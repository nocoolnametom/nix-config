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
  split-my-cbz = pkgs.callPackage ./split-my-cbz { };
  stash-vr = pkgs.callPackage ./stash-vr { };
  stashapp = pkgs.callPackage ./stashapp { };
  stashapp-tools = pkgs.callPackage ./stashapp-tools { };
  update-cbz-tags = pkgs.callPackage ./update-cbz-tags { };
  wakatime-zsh-plugin = pkgs.callPackage ./wakatime-zsh-plugin { };
}
