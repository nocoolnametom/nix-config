{
  pkgs ? import <nixpkgs> { },
  stdenv ? pkgs.stdenv,
  lib ? pkgs.lib,
  bash ? pkgs.bash,
  curl ? pkgs.curl,
  pup ? pkgs.pup,
  unzip ? pkgs.unzip,
  xmlstarlet ? pkgs.xmlstarlet,
  zip ? pkgs.zip,
  makeWrapper ? pkgs.makeWrapper,
}:
stdenv.mkDerivation {
  pname = "update-cbz-tags";
  version = "0.0.1"; # Bump this manually when we change the script
  src = ./.;
  buildInputs = [
    bash
    curl
    pup
    unzip
    xmlstarlet
    zip
  ];
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin
    cp update-cbz-tags.sh $out/bin/update-cbz-tags
    chmod +x $out/bin/update-cbz-tags
    wrapProgram $out/bin/update-cbz-tags \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          curl
          pup
          unzip
          xmlstarlet
          zip
        ]
      }
  '';
}
