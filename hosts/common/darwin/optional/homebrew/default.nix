{ lib, configVars, ... }:
with lib;
{
  homebrew.enable = mkDefault true;
  homebrew.user = mkDefault configVars.username;
  homebrew.onActivation.autoUpdate = mkDefault true;
  homebrew.onActivation.cleanup = mkDefault "uninstall";
  homebrew.onActivation.upgrade = mkDefault true;
  homebrew.brews = [
    # No current nixpkgs
    { name = "tfenv"; }
    { name = "podman"; }
    { name = "podman-compose"; }
  ];
  homebrew.casks = [
    # Podman should work better than docker on MacOS
    { name = "podman-desktop"; }
  ];
  homebrew.taps = [
    { name = "amar1729/formulae"; }
    { name = "homebrew/services"; }
  ];
}
