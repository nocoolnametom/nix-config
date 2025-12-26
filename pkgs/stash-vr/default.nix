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
  pkgVersion = "0.9.9";

  platforms = {
    aarch64-darwin = {
      name = "darwin_all";
      sha256 = "0xrc5qg609z9gwvf5hk6lnm3xm9bls1xz7ncn06vj3jxngg5cnry";
    };
    aarch64-linux = {
      name = "linux_arm64";
      sha256 = "1r7iw5xx8i032f0pslrd5lyjj2b1cf3y0afiwwfsahgfflvhjq86";
    };
    x86_64-linux = {
      name = "linux_amd64";
      sha256 = "0ngdp51v0wg0f8jxwdxva331xrdlddl51dj5l1cky3v5cis16np6";
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
