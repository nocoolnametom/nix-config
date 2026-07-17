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
  pkgVersion = "0.9.10";

  platforms = {
    aarch64-darwin = {
      name = "darwin_all";
      sha256 = "0scflcchabp6basdi5dv7gigpc4x3bfcrpcfsyg9blm4318a4h5z";
    };
    aarch64-linux = {
      name = "linux_arm64";
      sha256 = "0q0l02g7dw75iz3zp08x7bjqdf6j3p776xn8r5vkj55qp0hhpcfc";
    };
    x86_64-linux = {
      name = "linux_amd64";
      sha256 = "1slb5j90r9llnyga1lf02ipqq8lh6h65q00b1vnrs3k4p046fcv7";
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
