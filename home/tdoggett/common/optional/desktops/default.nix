{ pkgs, ... }:
{
  imports = [
    # Program configurations (if needing enabling that is below)
    ./vscode.nix
    ../browsers/brave.nix

    # Desktop-related Services (enable below)
    # ./services/swaync.nix
  ];

  # User-level GUI packages to have installed
  home.packages = with pkgs; [
    protonmail-desktop
    czkawka
    discord
    firefox
    foliate
    jellyfin-media-player
    kdeconnect
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

  fonts.fontconfig.enable = true;
  programs.brave.enable = true;
  programs.vscode.enable = true;
  programs.google-chrome.enable = true;

  services.gnome-keyring.enable = true;
}
