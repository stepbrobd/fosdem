{
  outputs =
    inputs:
    inputs.parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      perSystem =
        { lib
        , pkgs
        , system
        , self'
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
          checks.default = self'.packages.default.tests.default;
        };

      flake.overlays.default = final: prev: {
        fosdem = prev.callPackage (import ./default.nix) { };
      };
    };

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.parts.url = "github:hercules-ci/flake-parts";
  inputs.parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  inputs.systems.url = "github:nix-systems/default";
}
