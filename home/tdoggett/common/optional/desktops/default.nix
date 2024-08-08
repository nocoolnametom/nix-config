{ pkgs, ... }:
{
  imports = [
    # Window Manager
    ./hyprland

    # Program configurations (if needing enabling that is below)
    ./wofi.nix
    ./hyprlock.nix
    ./waybar.nix
    ../browsers/brave.nix

    # Desktop-related Services (enable below)
    ./services/swaync.nix
    ./services/hypridle.nix
    ./services/hyprpaper.nix
  ];

  # User-level GUI packages to have installed - See if any have Home Manager modules!
  home.packages = with pkgs; [
    discord
    firefox
    foliate
    jellyfin-media-player
    kitty
    # networkmanagerapplet # Used by Hyprland startup but I'm not sure if I need it installed otherwise
    obsidian
    slack
    vlc
    vscode
    xfce.thunar
    zed-editor
  ];

  wayland.windowManager.hyprland.enable = true;

  programs.wofi.enable = true;
  programs.hyprlock.enable = true;
  programs.waybar.enable = true;
  programs.brave.enable = true;

  services.swaync.enable = true;
  services.hypridle.enable = true;
  services.gnome-keyring.enable = true;

  # This is very machine-specific since it references monitors, it should probably be pulled in explicitly on the machine config.
  services.hyprpaper.enable = false;
}
