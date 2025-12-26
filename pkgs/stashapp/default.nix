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
  pkgVersion = "0.30.1";

  platforms = {
    aarch64-darwin = {
      name = "macos";
      sha256 = "045pz66527fcjzyh9b1xq738wd2k0ql408wy695crnb5qmqf0jf6";
    };
    aarch64-linux = {
      name = "linux-arm64v8";
      sha256 = "1281w6dx3a0ljwikmyml76bir28q50lr9xn5y56drpb1sbbvk2cx";
    };
    armv6l-linux = {
      name = "linux-arm32v6";
      sha256 = "1kph1jybdnc4s2rjm91kv0p2vprbshgi8y55k7csprjg39frk19v";
    };
    armv7l-linux = {
      name = "linux-arm32v7";
      sha256 = "1nbfq08q7k0dacayd9l0vyqr4ddn19is6ma4bxpw4lw91v969mdw";
    };
    x86_64-linux = {
      name = "linux";
      sha256 = "00gnk2m8j8kcscwdphckrjmaif9c2ffymj9amv96pcnzh391f05m";
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
