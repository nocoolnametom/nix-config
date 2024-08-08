{
  fetchurl,
  unzip,
  stdenv,
  ...
}:

stdenv.mkDerivation rec {
  pname = "homer";
  version = "24.05.01";

  src = fetchurl {
    urls = [ "https://github.com/bastienwirtz/${pname}/releases/download/v${version}/${pname}.zip" ];
    sha256 = "sha256-Ji/7BSKCnnhj4NIdGngTHcGRRbx9UWrx48bBsKkEj34=";
  };

  nativeBuildInputs = [ unzip ];

  dontInstall = true;

  sourceRoot = ".";

  unpackCmd = "${unzip}/bin/unzip -d $out $curSrc";
}
