{ pkgs, lib, ... }:
{
  imports = [
    # Browsers
    ./brave.nix
    ./firefox.nix
    ./google-chrome.nix

    # Editors & IDEs
    ./kitty.nix
    ./vscode.nix
    ./zed.nix

    # Communication
    ./discord.nix
    ./slack.nix

    # Productivity
    ./obsidian.nix

    # Media
    ./vlc.nix

    # Desktop-related Services
    ./services/waynergy.nix

    # Desktop utilities (clipboard history, trash)
    ./cliphist.nix
    ./trash.nix
  ];

  # User-level GUI packages to have installed (not modularized yet)
  home.packages = with pkgs; [
    unstable.protonmail-desktop
    czkawka
    foliate
    kdePackages.kdeconnect-kde
    networkmanagerapplet # having it installed allows the icon to show up correctly in system bars
    xfce.thunar
    # todoist-electron

    # Fonts
    cascadia-code
    font-awesome
    fira-code
    fira-code-symbols
    jetbrains-mono
    liberation_ttf
    powerline-fonts
    powerline-symbols
    nerd-fonts.symbols-only
    nerd-fonts.droid-sans-mono
  ];

  # home.pointerCursor.gtk.enable = true;

  gtk.enable = lib.mkDefault true;

  #fonts.fontconfig.enable = lib.mkDefault true;
  services.gnome-keyring.enable = lib.mkDefault true;
}
