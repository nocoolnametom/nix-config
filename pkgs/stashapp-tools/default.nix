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
    version = "0.2.49";
    src = p.fetchPypi {
      inherit pname version;
      sha256 = "sha256-QfmFwMU6l9E0F6fk6j7aWAqj/ji9nw6BoioZPI2/MyY=";
    };
    doCheck = false;
    propagatedBuildInputs = [
      # Specify dependencies
      p.requests
    ];
  })
]))
