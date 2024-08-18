{
  fetchurl,
  unzip,
  stdenv,
  ...
}:

stdenv.mkDerivation rec {
  pname = "homer";
  version = "24.05.1";

  src = fetchurl {
    urls = [ "https://github.com/bastienwirtz/${pname}/releases/download/v${version}/${pname}.zip" ];
    sha256 = "0zlg0jlv1hf6wgqnllbxpi2r3h8x2dw1l7fjw1ipi7l2482znbr6";
  };

  nativeBuildInputs = [ unzip ];

  dontInstall = true;

  sourceRoot = ".";

  unpackCmd = "${unzip}/bin/unzip -d $out $curSrc";
}
