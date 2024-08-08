{ configVars, osConfig, ... }:
{
  imports = [
    ########################## Required Configs ###########################
    ../common/core # required

    #################### Host-specific Optional Configs ####################
    ../common/optional/sops.nix
    ../common/optional/desktops

    ############### Service Configurations (Enable below) #################
    ../common/optional/services/gpg-agent.nix
  ];

  wayland.windowManager.hyprland.settings.monitor = [
    # "name,resolution,position,scale"
    "desc:Chimei Innolux Corporation 0x15E8,preferred,auto,1" # Laptop screen
    ",preferred,auto-left,1" # Other screens
  ];

  services.gpg-agent.enable = true;
  services.playerctld.enable = true;

  home = {
    stateVersion = "24.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
