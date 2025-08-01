{
  pkgs,
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
    common/optional/immersed.nix
    common/optional/desktops
    common/optional/desktops/hyprland.nix
    common/optional/devenv.nix
    common/optional/wakatime.nix

    ############### Service Configurations (Enable below) #################
    common/optional/services/ssh-agent.nix
    common/optional/services/gpg-agent.nix
    common/optional/services/syncthing.nix
  ];

  services.yubikey-touch-detector.enable = true;

  wayland.windowManager.hyprland.settings.monitor = [
    # Falback for all monitors already set up, named monitors go here
    # "name,                                 resolution, position,  scale"
    "desc:Chimei Innolux Corporation 0x1502, preferred,  0x0,       1" # Laptop screen
    "desc:Dell Inc. DELL S3221QS 2H1S6N3,    preferred,  auto-left, 1" # Big HDMI screen
  ];

  wayland.windowManager.hyprland.settings."$laptopScreen" = "eDP-1";
  wayland.windowManager.hyprland.settings."$bigExternalScreen" = "DP-1";

  services.waycorner.settings.main-monitor.output.description = "0x1502";
  services.waycorner.settings.side-monitor.output.description = "S3221QS 2H1S6N3";

  services.gpg-agent.enable = true;
  services.playerctld.enable = true;
  services.blueman-applet.enable = true;
  services.waynergy.host = "192.168.0.10";
  programs.git.userEmail = configVars.gitHubEmail;

  home.packages = with pkgs; [
    gnumake
    remmina
    bottles
    standardnotes
  ];

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
