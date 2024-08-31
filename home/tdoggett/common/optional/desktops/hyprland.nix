{ pkgs, lib, ... }:
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

  wayland.windowManager.hyprland.enable = lib.mkDefault true;

  programs.wofi.enable = lib.mkDefault true;
  programs.hyprlock.enable = lib.mkDefault true;
  programs.waybar.enable = lib.mkDefault true;

  services.swaync.enable = lib.mkDefault true;
  services.hypridle.enable = lib.mkDefault true;
}
