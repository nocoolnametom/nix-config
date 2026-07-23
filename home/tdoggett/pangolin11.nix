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
    common/optional/jj.nix
    common/optional/desktops
    common/optional/desktops/bluetooth-applet.nix
    common/optional/desktops/vscode.nix
    common/optional/devenv.nix
    common/optional/notification-leds.nix
    common/optional/wakatime.nix

    ############### Service Configurations (Enable below) #################
    common/optional/services/atuin.nix
    common/optional/services/gpg-agent.nix
    common/optional/services/syncthing.nix
  ];

  programs.atuin.settings.sync_address = "http://${configVars.networking.subnets.estel.ip}:${
    toString configVars.networking.ports.tcp."atuin-sync"
  }";

  services.yubikey-touch-detector.enable = true;

  services.playerctld.enable = true;
  programs.git.settings.user.email = configVars.gitHubEmail;

  home.packages = with pkgs; [
    bottles
    calibre
    gnumake
    helium-browser-flake
    orion-browser-flake
    ladybird
    megasync
    remmina
    standardnotes
    ticktick
    unzip
    zoom-us
  ];

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
