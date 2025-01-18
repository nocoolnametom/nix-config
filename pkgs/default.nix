# You can build these directly using 'nix build .#example'

{
  pkgs ? import <nixpkgs> { },
  inputs,
  ...
}:

rec {

  #################### Packages with external source ############################
  # These need to all be direct derivations for `nix flake check` to work!

  homer = pkgs.callPackage ./homer { };
  phanpy = pkgs.callPackage ./phanpy { };
  stashapp = pkgs.callPackage ./stashapp { };
  stashapp-tools = pkgs.callPackage ./stashapp-tools { };
  wakatime-zsh-plugin = pkgs.callPackage ./wakatime-zsh-plugin { };
}
