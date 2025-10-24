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
  pkgVersion = "0.29.1";

  platforms = {
    aarch64-darwin = {
      name = "macos";
      sha256 = "1pfan56jhd42sp7d1gb13d158vivamnzh6xn78lsj2kgaakxpcrb";
    };
    aarch64-linux = {
      name = "linux-arm64v8";
      sha256 = "0ba39201smsp2xh0cg96vvxri2218y206kslh28g0lnksdf8qn3v";
    };
    armv6l-linux = {
      name = "linux-arm32v6";
      sha256 = "0ak6m766g47z1fwlz0vgj4c1vwf72hq4yslkkbi2ys77g8zvag98";
    };
    armv7l-linux = {
      name = "linux-arm32v7";
      sha256 = "1gbsw7rd5wyywcgzlvqq6wvfdsnyw0cbc2gx4wvw8sajbqs0q10w";
    };
    x86_64-linux = {
      name = "linux";
      sha256 = "1mqfqssbc86xicd44xngh79xp415r34wb14v7bn0j1v1myg2f7c6";
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
