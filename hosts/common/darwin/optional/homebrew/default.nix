{ lib, configVars, ... }:
with lib;
{
  homebrew.enable = mkDefault true;
  homebrew.user = mkDefault configVars.username;
  homebrew.onActivation.autoUpdate = mkDefault true;
  homebrew.onActivation.cleanup = mkDefault "uninstall";
  homebrew.onActivation.upgrade = mkDefault true;
  homebrew.onActivation.extraFlags = [
    "--force-cleanup"
  ];
  # Taps should be tapped first, then then dependants can be enabled
  homebrew.taps = [
    { name = "deskflow/tap"; }
    { name = "bnjreece/loudcue"; }
  ];
  homebrew.brews = [
    # No current nixpkgs
    { name = "reddix"; }
    # Local LLM-Fit for Colima
    { name = "llmfit"; }
    # Crit AI Assistance - Tapped, comment first then uncomment
    { name = "tomasz-tomczyk/tap/crit"; }
    # macOS calendar query CLI — used by the sketchybar calendar widget.
    # Not in nixpkgs (macOS-only tool). Requires Calendar permission on first run.
    { name = "ical-buddy"; }
    # ThingM blink(1) USB LED control — provides /opt/homebrew/bin/blink1-tool
    # used by the notification-leds home-manager module. Not in nixpkgs.
    { name = "blink1"; }
  ];
  homebrew.casks = [
    # Podman should work better than docker on MacOS
    { name = "podman-desktop"; }
    # Deskflow - Might need to tap the cask first, if so comment this and rebuild then uncomment and rebuild again
    { name = "deskflow"; }
    # Handy - Not available on non-Linux via nixpkgs
    { name = "handy"; }
    # LoudCue - Tapped, comment first then uncomment if tap fails
    { name = "bnjreece/loudcue/loudcue"; }
  ];
}
