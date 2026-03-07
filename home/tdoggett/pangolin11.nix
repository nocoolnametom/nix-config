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
    common/optional/devenv.nix
    common/optional/wakatime.nix
    common/optional/stylix.nix # System-wide theming via Home Manager

    ############### Service Configurations (Enable below) #################
    common/optional/services/gpg-agent.nix
    common/optional/services/syncthing.nix
  ];

  services.yubikey-touch-detector.enable = true;

  services.gpg-agent.enable = true;
  services.playerctld.enable = true;
  services.blueman-applet.enable = true;
  programs.git.settings.user.email = configVars.gitHubEmail;

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

  # Stylix theme for this host
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/github-dark.yaml";
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
