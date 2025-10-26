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

    ############### Service Configurations (Enable below) #################
    common/optional/services/ssh-agent.nix
    common/optional/services/gpg-agent.nix
    common/optional/services/syncthing.nix
  ];

  services.yubikey-touch-detector.enable = true;

  services.gpg-agent.enable = true;
  services.playerctld.enable = true;
  services.blueman-applet.enable = true;
  services.waynergy.host = "192.168.0.10";
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

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
