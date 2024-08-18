# You can build these directly using 'nix build .#example'

{
  pkgs ? import <nixpkgs> { },
}:
rec {

  #################### Packages with external source ####################

  homer = pkgs.callPackage ./homer { };
  stashapp = pkgs.callPackage ./stashapp { };
  stashapp-tools = pkgs.callPackage ./stashapp-tools { };
  wakatime-zsh-plugin = pkgs.callPackage ./wakatime-zsh-plugin { };
  calibre-update = pkgs.callPackage ./calibre-update { };

}
