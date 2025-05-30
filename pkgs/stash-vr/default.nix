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
  pkgVersion = "0.8.4";

  platforms = {
    aarch64-darwin = {
      name = "darwin_arm64";
      sha256 = "037qcixq2lkvdc9cacmy9064ns3cz563k79pry922zik71pan1xz";
    };
    aarch64-linux = {
      name = "linux_arm64";
      sha256 = "08hk9r6v0mjcafw5nkf5cgp4ls17dml694z68zd12dbmw8n61wkz";
    };
    x86_64-linux = {
      name = "linux_amd64";
      sha256 = "0s4l4pvfm41b6b99yysvdnsj4nbpzwc8k1fzppja73sha5062mb7";
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
