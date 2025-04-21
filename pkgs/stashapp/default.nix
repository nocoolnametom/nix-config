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
  pkgVersion = "0.28.1";

  platforms = {
    aarch64-darwin = {
      name = "macos";
      sha256 = "0nz8j88b4balg0qs3kxapzyy1fjlcgif2jbhb4fnxjzr3xjkfiag";
    };
    aarch64-linux = {
      name = "linux-arm64v8";
      sha256 = "0i6vhkql7k081g1yz0333wizg6ayqjz5nh6q8mbz5vgvqgfbl13y";
    };
    armv6l-linux = {
      name = "linux-arm32v6";
      sha256 = "0mqz18k1n0fkxmgg5bcasy3xj5hhl63jx1a9k2cg5dfsgrgy9rfj";
    };
    armv7l-linux = {
      name = "linux-arm32v7";
      sha256 = "0sd3w7r7xq65k8hk8dgwjpyj91fnr0g0hsn533225j4azfhmzp9g";
    };
    x86_64-linux = {
      name = "linux";
      sha256 = "1xkv78f00ak93dmh96qgq3sc0jw22ldlhrjr0h8xzyailhjznljq";
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
