{
  pkgs ? import <nixpkgs> { },
  ...
}:

with pkgs;
stdenv.mkDerivation rec {
  version = "0.2.2";
  baseName = "wakatime-zsh-plugin";
  name = "${baseName}-${version}";

  src = fetchFromGitHub {
    rev = "7b3103d";
    owner = "sobolevn";
    repo = baseName;
    sha256 = "sha256-6isB3WWn79hKsUOlX/3yg7XeE0ZrigrXO3nVv4O4tl4=";
  };

  installPhase = ''
    mkdir -p $out
    cp -a * $out/
  '';
}
