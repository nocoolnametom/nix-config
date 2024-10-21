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
  pkgVersion = "0.27.2";

  platforms = {
    aarch64-darwin = {
      name = "macos";
      sha256 = "08hmibz9p3whsb4cqp2fh3li3pqv2g98sr5zi4b1l0wpj05b08b0";
    };
    aarch64-linux = {
      name = "linux-arm64v8";
      sha256 = "1ky0jv0sv9bwg1xa0793ii19mx56ndfli3b8igvv40kj0vxbyysq";
    };
    armv6l-linux = {
      name = "linux-arm32v6";
      sha256 = "09wmifwny530648v6l9hz0miqx3fd326iz9adw318cg6kwh68icz";
    };
    armv7l-linux = {
      name = "linux-arm32v7";
      sha256 = "1kr8r6gsnn529ihzhg93f73kd497095igchkil9rvvkwnnzzmq0x";
    };
    x86_64-linux = {
      name = "linux";
      sha256 = "1s52f93k6vbsg30q5iswhkv6h8r4v9sqdwi1w3vx6hxw4psydnwa";
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
