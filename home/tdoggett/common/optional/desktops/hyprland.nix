{ pkgs, ... }:
{
  imports = [
    # Window Manager
    ./hyprland

    # Program configurations (if needing enabling that is below)
    ./wofi.nix
    ./hyprlock.nix
    ./waybar.nix

    # Desktop-related Services (enable below)
    ./services/swaync.nix
    ./services/hypridle.nix
  ];

  wayland.windowManager.hyprland.enable = true;

  programs.wofi.enable = true;
  programs.hyprlock.enable = true;
  programs.waybar.enable = true;

  services.swaync.enable = true;
  services.hypridle.enable = true;
}
