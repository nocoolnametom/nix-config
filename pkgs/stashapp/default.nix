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
  pkgVersion = "0.26.2";

  platforms = {
    aarch64-darwin = {
      name = "macos";
      sha256 = "1hyfribi5l64nb6df15bdf0sx73j1xg4mlpx5jp89qg28ahjz8lr";
    };
    aarch64-linux = {
      name = "linux-arm64v8";
      sha256 = "0rlh3n6majkwrnmxj3d3wmhs8li7ljkrqjfhav9llygclwqw9ap0";
    };
    armv6l-linux = {
      name = "linux-arm32v6";
      sha256 = "0r5d2mdrnx8p416v6dadwlwvah35ca65wp0i5jcgh8rzbfbbf5m5";
    };
    armv7l-linux = {
      name = "linux-arm32v7";
      sha256 = "00ghq4aysccczy39rqj86vxpj6d20qc0ihicfb0nmhxvf7h8y4k3";
    };
    x86_64-linux = {
      name = "linux";
      sha256 = "07q0h32nd6w0bllvhnszv42h4s375rvfa0lm9v1as704sgfzr4z1";
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
