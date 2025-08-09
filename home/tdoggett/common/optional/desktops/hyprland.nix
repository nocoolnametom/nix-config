{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    # Window Manager
    ./hyprland

    # Program configurations (if needing enabling that is below)
    ./wofi.nix
    ./hyprlock.nix
    ./waybar.nix
    ./waycorner.nix

    # Desktop-related Services (enable below)
    ./services/swaync.nix
    ./services/hypridle.nix
  ]
  ++ (lib.optionals (builtins.hasAttr "hyprland" inputs) [
    # Home-Manager modules from the Flake input
    inputs.hyprland.homeManagerModules.default
  ]);

  wayland.windowManager.hyprland.enable = lib.mkDefault true;
  wayland.windowManager.hyprland.systemd.enable = lib.mkDefault false;

  programs.wofi.enable = lib.mkDefault true;
  programs.hyprlock.enable = lib.mkDefault true;
  programs.waybar.enable = lib.mkDefault true;

  services.swaync.enable = lib.mkDefault true;
  services.hypridle.enable = lib.mkDefault true;
}
