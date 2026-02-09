{ lib, configVars, ... }:
with lib;
{
  homebrew.enable = mkDefault true;
  homebrew.user = mkDefault configVars.username;
  homebrew.onActivation.autoUpdate = mkDefault true;
  homebrew.onActivation.cleanup = mkDefault "uninstall";
  homebrew.onActivation.upgrade = mkDefault true;
  # Taps should be tapped first, then then dependants can be enabled
  homebrew.taps = [
    { name = "deskflow/tap"; }
  ];
  homebrew.brews = [
    # No current nixpkgs
    { name = "reddix"; }
  ];
  homebrew.casks = [
    # Podman should work better than docker on MacOS
    { name = "podman-desktop"; }
    # Deskflow - Might need to tap the cask first, if so comment this and rebuild then uncomment and rebuild again
    { name = "deskflow"; }
  ];
}
