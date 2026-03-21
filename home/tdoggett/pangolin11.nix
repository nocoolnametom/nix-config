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

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
