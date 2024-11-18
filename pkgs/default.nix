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
  stashapp = pkgs.callPackage ./stashapp { };
  stashapp-tools = pkgs.callPackage ./stashapp-tools { };
  wakatime-zsh-plugin = pkgs.callPackage ./wakatime-zsh-plugin { };
  wp-theme-twentyten-ken = pkgs.callPackage ./wp-theme-twentyten-ken {
    inherit (inputs) wp-main;
  };
  myWpPlugins = pkgs.callPackage ./my-wp-plugins { inherit (inputs) wp-main; };
}
