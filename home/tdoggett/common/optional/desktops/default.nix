{ pkgs, lib, ... }:
{
  imports = [
    # Program configurations (if needing enabling that is below)
    ./brave.nix
    ./kitty.nix
    ./vscode.nix

    # Desktop-related Services (enable below)
    ./services/waynergy.nix
  ];

  # User-level GUI packages to have installed
  home.packages = with pkgs; [
    unstable.protonmail-desktop
    czkawka
    discord
    firefox
    foliate
    kdePackages.kdeconnect-kde
    networkmanagerapplet # having it installed allows the icon to show up correctly in system bars
    obsidian
    slack
    vlc
    xfce.thunar
    # todoist-electron
    unstable.zed-editor

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
  programs.brave.enable = lib.mkDefault true;
  programs.vscode.enable = lib.mkDefault true;
  programs.google-chrome.enable = lib.mkDefault true;

  services.gnome-keyring.enable = lib.mkDefault true;
}
