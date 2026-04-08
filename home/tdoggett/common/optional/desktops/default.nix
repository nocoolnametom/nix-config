{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [
    # Browsers
    ./brave.nix
    ./firefox.nix
    ./google-chrome.nix

    # Editors & IDEs
    ./kitty.nix
    ./vscode.nix

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
    thunar
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

  gtk.enable = lib.mkDefault true;
  # LEGACY BEHAVIOR (26.05): New default sets gtk4 theme to null (unmanaged) rather than
  # inheriting gtk3 theme. Keeping the gtk3 theme for visual consistency across GTK3/GTK4 apps.
  # To adopt new behavior: set to null and manage gtk4 theming separately (e.g. via Stylix).
  gtk.gtk4.theme = config.gtk.theme;

  # GNOME Keyring for app credential storage (VSCode, etc.)
  # Disable SSH component to avoid conflict with GPG agent
  services.gnome-keyring = {
    enable = lib.mkDefault true;
    components = lib.mkDefault [
      "pkcs11"
      "secrets"
    ]; # Exclude "ssh" component
  };
}
