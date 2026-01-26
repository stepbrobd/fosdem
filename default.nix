{
  lib,
  llvmPackages,
  meson,
  ninja,
  pkg-config,
  libbpf,
  prometheus-ebpf-exporter,
  testers,
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

  fixupPhase = ''
    runHook preFixup
    ${lib.getExe' llvmPackages.libllvm "llvm-strip"} -g $out/libexec/*.bpf.o
    runHook postFixup
  '';

  passthru = {
    tests.default = testers.runNixOSTest ./test;
    full = finalAttrs.overrideAttrs {
      postInstall = ''
        cp ${prometheus-ebpf-exporter}/examples/*.bpf.o $out/libexec/
        cp ${prometheus-ebpf-exporter}/examples/*.yaml  $out/libexec/
      '';
    };
  };
})
