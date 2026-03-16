{
  pkgs,
  lib,
  configVars,
  osConfig,
  ...
}:
{
  imports = [
    ########################## Required Configs ###########################
    common/core # required

    #################### Host-specific Optional Configs ####################
    common/optional/sops.nix
    common/optional/git.nix
    common/optional/desktops
    common/optional/desktops/bluetooth-applet.nix
    common/optional/claude.nix
    common/optional/devenv.nix
    common/optional/wakatime.nix
    common/optional/stylix.nix # System-wide theming via Home Manager

    ############### Service Configurations (Enable below) #################
    common/optional/services/gpg-agent.nix
    common/optional/services/syncthing.nix
  ];

  services.yubikey-touch-detector.enable = true;

  services.playerctld.enable = true;
  programs.git.settings.user.email = configVars.gitHubEmail;

  programs.claude.ollamaMachine = configVars.networking.subnets.barliman.name;

  home.packages = with pkgs; [
    bottles
    calibre
    gnumake
    helium-browser-flake
    remmina
    standardnotes
    ticktick
    unzip
  ];

  # Stylix fonts for this host (scheme inherits github-dark default from stylix.nix)
  stylix.fonts.serif.package = pkgs.appleFonts.sf-pro;
  stylix.fonts.serif.name = "SFProText Nerd Font";
  stylix.fonts.sansSerif.package = pkgs.appleFonts.sf-pro;
  stylix.fonts.sansSerif.name = "SFProDisplay Nerd Font";
  stylix.fonts.monospace.package = pkgs.appleFonts.sf-mono;
  stylix.fonts.monospace.name = "SFMono Nerd Font";

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
