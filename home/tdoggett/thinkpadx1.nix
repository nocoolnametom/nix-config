{
  configVars,
  osConfig,
  pkgs,
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
    common/optional/desktops/hyprland.nix
    common/optional/devenv.nix

    ############### Service Configurations (Enable below) #################
    common/optional/services/ssh-agent.nix
    common/optional/services/gpg-agent.nix
    common/optional/services/syncthing.nix
  ];

  wayland.windowManager.hyprland.settings.monitor = [
    # Falback for all monitors already set up, named monitors go here
    # "name,                                 resolution, position,  scale"
    "desc:Chimei Innolux Corporation 0x15E8, preferred,  0x0,       1" # Laptop screen
    "desc:Dell Inc. DELL S3221QS 2H1S6N3,    preferred,  auto-left, 1" # Big HDMI screen
  ];

  services.gpg-agent.enable = true;
  services.playerctld.enable = true;
  services.blueman-applet.enable = true;
  programs.git.userEmail = configVars.gitHubEmail;

  home.packages = with pkgs; [
    gnumake
    remmina
    zen-browser-flake.default
  ];

  home = {
    stateVersion = "24.11";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
