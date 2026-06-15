{
  lib,
  stdenv,
  swift,
}:
stdenv.mkDerivation {
  pname = "display-info";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ swift ];

  buildPhase = ''
    runHook preBuild
    swiftc -O display-info.swift -o display-info
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp display-info $out/bin/
    runHook postInstall
  '';

  meta = {
    description = "Print macOS display info — max safe-area-inset top and the built-in display index — as shell-sourceable KEY=value lines.";
    platforms = lib.platforms.darwin;
    mainProgram = "display-info";
  };
}
