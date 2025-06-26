{
  pkgs ? import <nixpkgs> { },
  lib,
  fetchurl,
  autoPatchelfHook,
  stdenv,
  openssl,
  stashapp-tools ? pkgs.callPackage ../stashapp-tools { },
  makeWrapper,
  ...
}:

let
  pkgVersion = "0.8.8";

  platforms = {
    aarch64-darwin = {
      name = "darwin_arm64";
      sha256 = "0i58wb5l8hn0qscqnhpxm7mqv5grclz0bc2srb7gja0x9dwn4s28";
    };
    aarch64-linux = {
      name = "linux_arm64";
      sha256 = "10z5psn6l7k3jqf68b68d1r3hys3srrblnsh2s3b2p3scqhih8xh";
    };
    x86_64-linux = {
      name = "linux_amd64";
      sha256 = "0gqxdba9zryqn5ii1xr2kb33s05h3jcb5nk5ynad61b9cvhjiqps";
    };
  };

  plat =
    if (lib.hasAttrByPath [ stdenv.hostPlatform.system ] platforms) then
      platforms.${stdenv.hostPlatform.system}
    else
      throw "Unsupported architecture: ${stdenv.hostPlatform.system}";
in
stdenv.mkDerivation rec {
  name = "stash-vr-${pkgVersion}";
  version = "${pkgVersion}";

  src = fetchurl {
    inherit (plat) sha256;
    url = "https://github.com/o-fl0w/stash-vr/releases/download/v${pkgVersion}/stash-vr_${pkgVersion}_${plat.name}.tar.gz";
    executable = false;
  };

  unpackPhase = ''
    tar xzvf ${src}
  '';

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    openssl
    makeWrapper
    stashapp-tools
  ];

  installPhase = ''
    mkdir -p $out/bin
    mv stash-vr $out/bin/stash-vr
  '';

  meta = {
    homepage = "https://github.com/o-fl0w/stash-vr";
    description = "Accounting Organizer VR Helper";
    license = lib.licenses.agpl3Only;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
