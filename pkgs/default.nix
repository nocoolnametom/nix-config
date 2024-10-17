# You can build these directly using 'nix build .#example'

{
  pkgs ? import <nixpkgs> { },
  ...
}:

rec {

  #################### Packages with external source ############################
  # These need to all be direct derivations for `nix flake check` to work!

  homer = pkgs.callPackage ./homer { };
  stashapp = pkgs.callPackage ./stashapp { };
  stashapp-tools = pkgs.callPackage ./stashapp-tools { };
  wakatime-zsh-plugin = pkgs.callPackage ./wakatime-zsh-plugin { };
  xpc_set_event_stream_handler = pkgs.callPackage ./xpc_set_event_stream_handler { };
}
