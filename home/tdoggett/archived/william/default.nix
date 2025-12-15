{ configVars, osConfig, ... }:
{
  imports = [
    ########################## Required Configs ###########################
    ../../common/core # required

    #################### Host-specific Optional Configs ####################
    ../../common/optional/services/ssh-agent.nix
    ../../common/optional/sops.nix
    ../../common/optional/git.nix
  ];

  programs.git.settings.user.email = configVars.gitHubEmail;
  programs.nh.flake = "/etc/nixos";

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
