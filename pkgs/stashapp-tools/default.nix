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
    version = "0.2.59";
    pyproject = true;
    src = p.fetchPypi {
      inherit pname version;
      sha256 = "sha256-Y52YueWHp8C2FsnJ01YMBkz4O2z4d7RBeCswWGr8SjY=";
    };
    build-system = [ p.setuptools ];
    doCheck = false;
    propagatedBuildInputs = [
      # Specify dependencies
      p.requests
    ];
  })
]))
