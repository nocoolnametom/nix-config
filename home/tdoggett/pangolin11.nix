{
  pkgs,
  lib,
  configVars,
  inputs,
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
    common/optional/desktops/plasma6.nix
    common/optional/desktops/vscode.nix
    common/optional/devenv.nix
    common/optional/notification-leds.nix
    common/optional/wakatime.nix
    common/optional/smolcoder.nix

    ############### Service Configurations (Enable below) #################
    common/optional/services/gpg-agent.nix
    common/optional/services/syncthing.nix
    common/optional/desktops/services/deskflow.nix
  ];

  programs.hermes = {
    enable = true;
    profiles.default.plugins.enabled = [
      "next-prompt"
      "herald-push"
    ];
  };

  services.yubikey-touch-detector.enable = true;

  services.playerctld.enable = true;
  programs.git.settings.user.email = configVars.gitHubEmail;

  home.packages = with pkgs; [
    bottles
    calibre
    gnumake
    helium-browser-flake
    # Lemonade desktop app (Tauri client). Connects to a remote lemond over the network.
    inputs.nix-amd-ai.packages.${pkgs.stdenv.hostPlatform.system}.lemonade.tauri-app
    # Hermes Agent desktop app (Electron). Add the remote Hermes as a connection in the app.
    inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.desktop
    orion-browser-flake
    megasync
    remmina
    standardnotes
    unstable.ticktick
    unzip
    zoom-us
  ];

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
