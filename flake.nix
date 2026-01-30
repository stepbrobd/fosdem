{
  outputs =
    inputs:
    inputs.parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      perSystem =
        {
          lib,
          pkgs,
          system,
          inputs',
          self',
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ inputs.self.overlays.default ];
          };

          devShells.default = (pkgs.mkShell.override { stdenv = pkgs.stdenvNoCC; }) {
            hardeningDisable = [ "all" ];

            inputsFrom = [
              pkgs.slides
            ]
            ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
              pkgs.fosdem
            ];

            packages =
              with pkgs;
              (lib.flatten [
                bear
                (with llvmPackages; [
                  clang
                  libllvm
                ])
                (lib.optionals stdenv.isLinux [
                  inputs'.nxc.packages.nixos-compose
                  bpftools
                  bpftrace
                  linuxHeaders
                ])
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

          checks.default = self'.packages.default.tests.default;

          packages = rec {
            inherit (pkgs) fosdem slides;
            default = fosdem;
          }
          // inputs.nxc.lib.compose {
            inherit (inputs) nixpkgs;
            inherit system;
            composition = ./test;
          };
        };

      flake.overlays.default = final: prev: {
        fosdem = prev.callPackage (import ./default.nix) { };
        slides = prev.callPackage (import ./doc) { };
      };
    };

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.parts.url = "github:hercules-ci/flake-parts";
  inputs.parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  inputs.systems.url = "github:nix-systems/default";
  inputs.nxc.url = "github:oar-team/nixos-compose";
}
