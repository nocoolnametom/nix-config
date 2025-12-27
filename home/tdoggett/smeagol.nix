{
  pkgs,
  lib,
  config,
  configVars,
  osConfig,
  inputs,
  ...
}:
{
  imports = [
    ########################## Required Configs ###########################
    common/core # required - remember to include a sops config below!

    #################### Host-specific Optional Configs ####################
    common/optional/services/ssh-agent.nix
    common/optional/sops.nix
    common/optional/flatpak.nix
    common/optional/git.nix
    common/optional/immersed.nix
    common/optional/desktops # Includes brave, kitty, cliphist, trash, etc.

    ############### Service Configurations (Enable below) #################
    common/optional/services/ssh-agent.nix
    common/optional/services/gpg-agent.nix
    common/optional/services/syncthing.nix
  ];

  programs.git.settings.user.email = configVars.gitHubEmail;
  services.gpg-agent.enable = true;
  services.blueman-applet.enable = true;

  # Custom packages are already overlaid into the provided `pkgs`
  home.packages = with pkgs; [
    bottles
    handbrake
    helium-browser-flake
  ];

  # Flatpaks
  services.flatpak.packages = [
    # Until I figure out how to do this headlessly, this is like Flowframes
    {
      appId = "io.github.tntwise.REAL-Video-Enhancer";
      origin = "flathub";
    }
  ];

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = lib.mkForce "/home/${configVars.username}";
    sessionVariables.TERM = lib.mkForce "xterm-256color";
    sessionVariables.TERMINAL = lib.mkForce "";
  };
}
