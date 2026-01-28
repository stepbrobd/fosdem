{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.prometheus;
in
{
  networking.firewall.enable = false;

  environment.systemPackages = [ pkgs.bpftools ];

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
    names = [ "main" ];
  };

  systemd.services.prometheus-ebpf-exporter.serviceConfig = rec {
    # run as root or programs using `bpf_probe_write_user` will fail to load
    # https://docs.ebpf.io/linux/helper-function/bpf_probe_write_user/
    # this already allow writing arbitrary data to userspace program anyways...
    User = lib.mkForce "root";
    Group = lib.mkForce "root";
    DynamicUser = lib.mkForce false;
    NoNewPrivileges = lib.mkForce false;
    # for required caps, check ebpf exporter readme
    # https://github.com/cloudflare/ebpf_exporter
    AmbientCapabilities = lib.mkForce [
      "CAP_BPF"
      "CAP_DAC_READ_SEARCH"
      "CAP_IPC_LOCK"
      "CAP_NET_ADMIN"
      "CAP_PERFMON"
      "CAP_SYSLOG"
      "CAP_SYS_ADMIN"
      "CAP_SYS_RESOURCE"
    ];
    CapabilityBoundingSet = AmbientCapabilities;
    # the collector itself is enabled in the modules imported above
    ExecStart =
      let
        cfg = config.services.prometheus.exporters.ebpf;
        fosdem = (pkgs.callPackage ../default.nix { }).full;
      in
      lib.mkForce ''
        ${lib.getExe pkgs.prometheus-ebpf-exporter} \
          --config.dir=${fosdem}/libexec \
          --config.names=${lib.concatStringsSep "," cfg.names} \
          --web.listen-address ${cfg.listenAddress}:${toString cfg.port}
      '';
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
}
