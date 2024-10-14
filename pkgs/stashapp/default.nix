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
  pkgVersion = "0.27.1";

  platforms = {
    aarch64-darwin = {
      name = "macos";
      sha256 = "0ii2qdb3kapq7fc8gr1d0apmjfs24f9aa7kpbcvkyh59p8c6aqmx";
    };
    aarch64-linux = {
      name = "linux-arm64v8";
      sha256 = "1rzdx17rs097df91bvdcdil4k8hp086isl3p8lfzmj3fcxv36hdv";
    };
    armv6l-linux = {
      name = "linux-arm32v6";
      sha256 = "12j213mvd00x6qpzd77bkwgid8pd2hf0gi7q1vsdlsrs9l7vk5nq";
    };
    armv7l-linux = {
      name = "linux-arm32v7";
      sha256 = "0d2d44y477saf18najcbsv7kcmmwzvng953izmgvlfl3cdbnh8iy";
    };
    x86_64-linux = {
      name = "linux";
      sha256 = "04flg86970sfaz4fy240djq8rk54zyvllvj2zlyf4rl2gvmlfpb0";
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
