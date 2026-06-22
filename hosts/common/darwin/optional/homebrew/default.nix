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
  homebrew.brews = [
    # Control Litra Glow light
    { name = "litra"; }
    # No current nixpkgs
    { name = "reddix"; }
    # Local LLM-Fit for Colima
    { name = "llmfit"; }
    # Crit AI Assistance
    { name = "tomasz-tomczyk/tap/crit"; }
    # macOS calendar query CLI
    { name = "ical-buddy"; }
    # ThingM blink(1) USB LED control — provides blink1-tool
    { name = "blink1"; }
    # Automate Litra with Webcam
    { name = "timrogers/tap/litra-autotoggle"; }
    # Hunk Diff Viewer
    { name = "modem-dev/tap/hunk"; }
  ];
  homebrew.casks = [
    # Podman should work better than docker on MacOS
    { name = "podman-desktop"; }
    # Deskflow
    { name = "deskflow/tap/deskflow"; }
    # Handy - Not available on non-Linux via nixpkgs
    { name = "handy"; }
    # LoudCue
    { name = "bnjreece/loudcue/loudcue"; }
    # Notchy
    { name = "vishvavariya/notchy/notchy"; }
    # SwipeAeroSpace
    { name = "mediosz/tap/swipeaerospace"; }
    # KindaVim
    { name = "kindavim"; }
  ];
}
