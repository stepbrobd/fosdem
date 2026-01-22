{
  lib,
  llvmPackages,
  meson,
  ninja,
  pkg-config,
  libbpf,
  prometheus-ebpf-exporter,
  # testers,
}:

llvmPackages.stdenv.mkDerivation (finalAttrs: {
  pname = "fosdem";
  version = "2026.131.0";

  src =
    with lib.fileset;
    toSource {
      root = ./.;
      fileset = unions [
        ./src
        ./include
        ./meson.build
      ];
    };

  hardeningDisable = [ "all" ];

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [ libbpf ];

  dontFixup = true;

  passthru = {
    # tests.exporter = testers.runNixOSTest ./test.nix;
    full = finalAttrs.overrideAttrs {
      postInstall = ''
        cp ${prometheus-ebpf-exporter}/examples/*.bpf.o $out/libexec/
        cp ${prometheus-ebpf-exporter}/examples/*.yaml  $out/libexec/
      '';
    };
  };
})
