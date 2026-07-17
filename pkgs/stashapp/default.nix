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
  pkgVersion = "0.31.1";

  platforms = {
    aarch64-darwin = {
      name = "macos";
      sha256 = "0ab7ll83fqx4ab6gky754gpmrql9nsn6sg674rdrrrw2b0m0w2d4";
    };
    aarch64-linux = {
      name = "linux-arm64v8";
      sha256 = "0m15xphpmzccpxlnacgpwd81mphyamb3da7735k9d3vzplmvlj1y";
    };
    armv6l-linux = {
      name = "linux-arm32v6";
      sha256 = "0r1hm0gfnzki2skfqnilsirp73dgp8nsrn7i5ii4vlszmsg2319c";
    };
    armv7l-linux = {
      name = "linux-arm32v7";
      sha256 = "1arl7xlwwz4zkc8ivfb2lkl72f9pq8iah6mdyxs8afh2drds9rim";
    };
    x86_64-linux = {
      name = "linux";
      sha256 = "1bqi94l0gs806hyavzaczx9gk6bgvsg1c315xlrbx1hk4vqsczla";
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
    mainProgram = "stashapp";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "armv6l-linux"
      "armv7l-linux"
      "x86_64-linux"
    ];
  };
}
