{ pkgs, ... }:
{
  imports = [
    # Window Manager
    ./hyprland

    # Program configurations (if needing enabling that is below)
    ./wofi.nix
    ./hyprlock.nix
    ./waybar.nix
    ./vscode.nix
    ../browsers/brave.nix

    # Desktop-related Services (enable below)
    ./services/swaync.nix
    ./services/hypridle.nix
  ];

  # User-level GUI packages to have installed
  home.packages = with pkgs; [
    protonmail-desktop
    czkawka
    discord
    firefox
    foliate
    jellyfin-media-player
    networkmanagerapplet # having it installed allows the icon to show up correctly in waybar
    obsidian
    slack
    vlc
    xfce.thunar
    todoist-electron
    zed-editor

    # Fonts
    cascadia-code
    font-awesome
    fira-code
    fira-code-symbols
    jetbrains-mono
    liberation_ttf
    powerline-fonts
    powerline-symbols
    (nerdfonts.override {
      fonts = [
        "NerdFontsSymbolsOnly"
        "DroidSansMono"
      ];
    })
  ];

  home.pointerCursor.gtk.enable = true;

  gtk.enable = true;

  wayland.windowManager.hyprland.enable = true;

  fonts.fontconfig.enable = true;

  programs.wofi.enable = true;
  programs.hyprlock.enable = true;
  programs.waybar.enable = true;
  programs.brave.enable = true;
  programs.vscode.enable = true;
  programs.google-chrome.enable = true;

  services.swaync.enable = true;
  services.hypridle.enable = true;
  services.gnome-keyring.enable = true;
}
