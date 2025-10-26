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
    common/optional/devenv.nix

    ############### Service Configurations (Enable below) #################
    common/optional/services/ssh-agent.nix
    common/optional/services/gpg-agent.nix
    common/optional/services/syncthing.nix
  ];

  services.gpg-agent.enable = true;
  services.playerctld.enable = true;
  services.blueman-applet.enable = true;
  programs.git.settings.user.email = configVars.gitHubEmail;

  home.packages = with pkgs; [
    gnumake
    remmina
  ];

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
