{
  fetchurl,
  unzip,
  stdenv,
  ...
}:

stdenv.mkDerivation rec {
  pname = "homer";
  version = "25.05.2";

  src = fetchurl {
    urls = [ "https://github.com/bastienwirtz/${pname}/releases/download/v${version}/${pname}.zip" ];
    sha256 = "079zvad6l977izcam2r2h2jy4hdwbppbn6rypr17cy3ixpn8zfg6";
  };

  nativeBuildInputs = [ unzip ];

  dontInstall = true;

  sourceRoot = ".";

  unpackCmd = "${unzip}/bin/unzip -d $out $curSrc";
}
