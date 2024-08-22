{ configVars, osConfig, ... }:
{
  imports = [
    ########################## Required Configs ###########################
    ../common/core # required

    #################### Host-specific Optional Configs ####################
    ../common/optional/sops.nix
    ../common/optional/git.nix
    ../common/optional/desktops

    ############### Service Configurations (Enable below) #################
    ../common/optional/services/gpg-agent.nix
  ];

  services.gpg-agent.enable = true;
  services.playerctld.enable = true;
  services.blueman-applet.enable = true;
  programs.git.userEmail = configVars.gitHubEmail;

  home = {
    stateVersion = "24.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
