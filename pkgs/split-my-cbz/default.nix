{
  pkgs ? import <nixpkgs> { },
  stdenv ? pkgs.stdenv,
  lib ? pkgs.lib,
  bash ? pkgs.bash,
  zip ? pkgs.zip,
  unzip ? pkgs.unzip,
  xmlstarlet ? pkgs.xmlstarlet,
  makeWrapper ? pkgs.makeWrapper,
}:
stdenv.mkDerivation rec {
  pname = "split-my-cbz";
  version = "0.0.1"; # Bump this manually when we change the script
  src = builtins.path {
    path = ./.;
    name = "${pname}-source";
  };
  buildInputs = [
    bash
    zip
    unzip
    xmlstarlet
  ];
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin
    cp split-my-cbz.sh $out/bin/split-my-cbz
    chmod +x $out/bin/split-my-cbz
    wrapProgram $out/bin/split-my-cbz \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          zip
          unzip
          xmlstarlet
        ]
      }
  '';
}
