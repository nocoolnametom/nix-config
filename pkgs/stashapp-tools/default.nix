{
  pkgs ? import <nixpkgs> { },
  ...
}:

(pkgs.python3.withPackages (p: [
  p.beautifulsoup4
  p.cloudscraper
  p.configparser
  # p.libpath
  p.lxml
  p.progressbar
  p.requests
  # yt-dlp
  (p.buildPythonPackage rec {
    pname = "stashapp-tools";
    version = "0.2.58";
    src = p.fetchPypi {
      inherit pname version;
      sha256 = "sha256-krruLbBI4FMruoXPiJEde9403hY7se6aeDsO+AqA8jo=";
    };
    doCheck = false;
    propagatedBuildInputs = [
      # Specify dependencies
      p.requests
    ];
  })
]))
