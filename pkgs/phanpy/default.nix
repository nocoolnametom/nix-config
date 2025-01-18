{
  fetchurl,
  unzip,
  stdenv,
  ...
}:

stdenv.mkDerivation rec {
  pname = "phanpy";
  version = "2024.12.28.119d4b0";

  src = fetchurl {
    urls = [ "https://github.com/cheeaun/${pname}/releases/download/${version}/${pname}-dist.zip" ];
    sha256 = "1fc3zwmvqyvsykmcjda9cddcv20x8cjwvjz9iwiq089sccr4a447";
  };

  nativeBuildInputs = [ unzip ];

  dontInstall = true;

  sourceRoot = ".";

  unpackCmd = "${unzip}/bin/unzip -d $out $curSrc";
}
