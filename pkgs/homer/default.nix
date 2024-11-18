{
  fetchurl,
  unzip,
  stdenv,
  ...
}:

stdenv.mkDerivation rec {
  pname = "homer";
  version = "24.11.4";

  src = fetchurl {
    urls = [ "https://github.com/bastienwirtz/${pname}/releases/download/v${version}/${pname}.zip" ];
    sha256 = "0lafa8r5lc66ph0jxmmxr661xrrnx2wv81h5ir844b99f28cg4f2";
  };

  nativeBuildInputs = [ unzip ];

  dontInstall = true;

  sourceRoot = ".";

  unpackCmd = "${unzip}/bin/unzip -d $out $curSrc";
}
