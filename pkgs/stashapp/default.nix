{
  pkgs ? import <nixpkgs> { },
  lib,
  fetchurl,
  autoPatchelfHook,
  stdenv,
  openssl,
  ffmpeg,
  sqlite,
  stashapp-tools ? pkgs.callPackage ../stashapp-tools { },
  makeWrapper,
  ...
}:

let
  pkgVersion = "0.29.3";

  platforms = {
    aarch64-darwin = {
      name = "macos";
      sha256 = "034w7n9sphdphgh1fh3sm2b9inag3g82lsq6230rsks3cni4axnq";
    };
    aarch64-linux = {
      name = "linux-arm64v8";
      sha256 = "1bbfynxkidjr9brbz8zj0fh40f457q89hijhhhv28fbl75frcwax";
    };
    armv6l-linux = {
      name = "linux-arm32v6";
      sha256 = "1hmrlldlcb6nyqa5rdl4q12kgplv6vyxrm3r04r6mbmx9ndmv8y5";
    };
    armv7l-linux = {
      name = "linux-arm32v7";
      sha256 = "0vwync5f9f2i6ch81mhv9jwlxxdn3qpa99va5k6yd8plgqgkq3bs";
    };
    x86_64-linux = {
      name = "linux";
      sha256 = "1n4yp7fdl0sknac4l4y8463hbcqrv85xg8mf5zc6fk21my1vjczx";
    };
  };

  plat =
    if (lib.hasAttrByPath [ stdenv.hostPlatform.system ] platforms) then
      platforms.${stdenv.hostPlatform.system}
    else
      throw "Unsupported architecture: ${stdenv.hostPlatform.system}";
in
stdenv.mkDerivation rec {
  name = "stash-${pkgVersion}";
  version = "${pkgVersion}";

  executable = fetchurl {
    inherit (plat) sha256;
    url = "https://github.com/stashapp/stash/releases/download/v${pkgVersion}/stash-${plat.name}";
    executable = true;
  };

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    ffmpeg
    openssl
    sqlite
    makeWrapper
    stashapp-tools
  ];

  installPhase = ''
    mkdir -p $out/bin
    makeWrapper "${executable}" "$out/bin/stashapp" --prefix PATH ":" "${
      lib.makeBinPath [
        ffmpeg
        stashapp-tools
      ]
    }"
  '';

  meta = {
    homepage = "https://stashapp.cc";
    description = "Accounting Organizer";
    license = lib.licenses.agpl3Only;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "armv6l-linux"
      "armv7l-linux"
      "x86_64-linux"
    ];
  };
}
