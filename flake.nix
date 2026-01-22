{
  outputs =
    inputs:
    inputs.parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      perSystem =
        { lib
        , pkgs
        , system
        , ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.default ];
          };

          devShells.default = (pkgs.mkShell.override { stdenv = pkgs.stdenvNoCC; }) {
            hardeningDisable = [ "all" ];
            packages =
              with pkgs;
              (lib.flatten [
                pkg-config
                (with llvmPackages; [
                  bintools
                  clang
                ])
                (lib.optionals stdenv.isLinux [
                  bpftools
                  bpftrace
                  libbpf
                  linuxHeaders
                ])

                bear
                # deno
                findutils

                meson
                ninja

                (typst.withPackages (
                  _: with _; [
                    cetz
                    polylux
                  ]
                ))
                typstyle
              ]);
          };

          formatter = pkgs.writeShellScriptBin "formatter" ''
            set -eoux pipefail
            shopt -s globstar
            # ${lib.getExe pkgs.deno} fmt readme.md
            ${lib.getExe pkgs.findutils} . -regex '.*\.\(c\|h\)' -exec ${lib.getExe' pkgs.clang-tools "clang-format"} -style=LLVM -i {} \;
            ${lib.getExe pkgs.nixpkgs-fmt} .
            ${lib.getExe pkgs.typstyle} --inplace **/*.typ
          '';

          packages.default = pkgs.fosdem;
        };

      flake.overlays.default = final: prev: {
        fosdem = prev.callPackage (import ./default.nix) { };
      };

      flake.nixosModules = {
        kernel =
          { lib, pkgs, ... }:
          {
            boot.supportedFilesystems.zfs = lib.mkForce false;
            boot.initrd.supportedFilesystems.zfs = lib.mkForce false;

            boot.kernelPackages =
              lib.pipe
                (pkgs.linuxKernel.kernels.linux_latest.override {
                  structuredExtraConfig = with lib.kernel; {
                    BPF_KPROBE_OVERRIDE = lib.mkForce yes;
                    FUNCTION_ERROR_INJECTION = lib.mkForce yes;
                  };
                })
                (
                  with pkgs;
                  [
                    linuxPackagesFor
                    recurseIntoAttrs
                  ]
                );
          };

        exporter =
          { config, ... }:

          let
            cfg = config.services.prometheus;
          in
          {
            services.caddy = {
              enable = true;
              virtualHosts."http://${config.networking.hostName}" = {
                extraConfig = ''
                  handle_path /prometheus/* {
                    reverse_proxy  [::]:${toString cfg.port}
                  }

                  handle_path /loki/* {
                    reverse_proxy  [::]:${toString config.services.loki.configuration.server.http_listen_port}
                  }
                '';
              };
            };

            services.prometheus = {
              enable = true;
              globalConfig = {
                scrape_interval = "250ms";
                scrape_timeout = "250ms";
              };
              listenAddress = "[::]";
            };

            # node exporter
            services.prometheus.exporters.node = {
              enable = true;
              enabledCollectors = [ "systemd" ];
              listenAddress = "[::]";
            };

            # ebpf exporter
            # https://github.com/nixos/nixpkgs/blob/master/nixos/modules/services/monitoring/prometheus/exporters/ebpf.nix
            # override exec start
            services.prometheus.exporters.ebpf = {
              enable = true;
              # we are not enabling any bpf program here
              # see the call site (in the nixos vm test)
            };

            services.prometheus.scrapeConfigs = [
              {
                job_name = "prometheus-node-exporter";
                static_configs = [
                  { targets = [ "[::]:${toString cfg.exporters.node.port}" ]; }
                ];
              }
              {
                job_name = "prometheus-ebpf-exporter";
                static_configs = [
                  { targets = [ "[::]:${toString cfg.exporters.ebpf.port}" ]; }
                ];
              }
            ];

            # logging
            services.loki = {
              enable = true;
              extraFlags = [ "-print-config-stderr" ];

              configuration = {
                analytics.reporting_enabled = false;
                auth_enabled = false;

                server = {
                  http_listen_address = "::";
                  http_listen_port = 3100;
                  grpc_listen_port = 0;
                };

                ingester = {
                  lifecycler = {
                    address = "::";
                    ring = {
                      kvstore.store = "inmemory";
                      replication_factor = 1;
                    };
                  };
                  chunk_idle_period = "1h";
                  max_chunk_age = "1h";
                  chunk_target_size = 999999;
                  chunk_retain_period = "30s";
                };

                schema_config.configs = [
                  {
                    from = "2024-04-01";
                    object_store = "filesystem";
                    store = "tsdb";
                    schema = "v13";
                    index = {
                      prefix = "index_";
                      period = "24h";
                    };
                  }
                ];

                storage_config = with config.services.loki; {
                  filesystem.directory = "${dataDir}/chunks";
                  tsdb_shipper = {
                    active_index_directory = "${dataDir}/tsdb-index";
                    cache_location = "${dataDir}/tsdb-cache";
                    cache_ttl = "24h";
                  };
                };

                limits_config = {
                  reject_old_samples = true;
                  reject_old_samples_max_age = "168h";
                };

                table_manager = {
                  retention_deletes_enabled = false;
                  retention_period = "0s";
                };

                compactor = {
                  working_directory = config.services.loki.dataDir;
                  compactor_ring.kvstore.store = "inmemory";
                };
              };
            };

            # still logging
            services.promtail = {
              enable = true;

              configuration = {
                server = {
                  http_listen_address = "::";
                  http_listen_port = 3180;
                  grpc_listen_port = 0;
                };

                positions = {
                  filename = "/tmp/positions.yaml";
                };

                clients = [
                  {
                    url = "http://[::]:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push";
                  }
                ];

                scrape_configs = [
                  {
                    job_name = "journal";
                    journal = {
                      max_age = "24h";
                      labels = {
                        job = "systemd-journal";
                        host = config.networking.hostName;
                      };
                    };
                    relabel_configs = [
                      {
                        source_labels = [ "__journal__systemd_unit" ];
                        target_label = "unit";
                      }
                    ];
                  }
                ];
              };
            };
          };

        collector = {
          services.grafana = {
            enable = true;
            settings = {
              server = {
                http_addr = "::";
                http_port = 80;
              };

              analytics = {
                check_for_updates = false;
                check_for_plugin_updates = false;
                feedback_links_enabled = false;
                reporting_enabled = false;
              };

              # we will only be using grafana as ephemeral service
              # so disable https setup and only create admin user
              users.allow_org_create = false;
              users.allow_sign_up = false;
              # set a very low number here so we can get high resolution data
              dashboards.min_refresh_interval = "0.01ms";
              security = {
                disable_gravatar = true;
                cookie_secure = false;
                disable_initial_admin_creation = false;
                admin_user = "admin";
                admin_password = "admin";
                admin_email = "admin@localhost";
              };
            };
          };
        };
      };
    };

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.parts.url = "github:hercules-ci/flake-parts";
  inputs.parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  inputs.systems.url = "github:nix-systems/default";
}
