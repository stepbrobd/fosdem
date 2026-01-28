{
  lib,
  stdenvNoCC,
  typst,
}:

stdenvNoCC.mkDerivation {
  name = "slides";
  version = "2026.131.0";

  src =
    with lib.fileset;
    toSource {
      root = ./.;
      fileset = unions [
        ./fosdem.typ
        ./ensl.png
        ./inria.png
        ./uga.png
      ];
    };

  nativeBuildInputs = [
    (typst.withPackages (
      _: with _; [
        cetz
        muchpdf
        polylux
      ]
    ))
  ];

  buildPhase = ''
    runHook preBuild
    typst compile fosdem.typ slides.pdf
    typst compile --features html fosdem.typ slides.html
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out; mv slides.* $out/
    runHook postInstall
  '';
}
