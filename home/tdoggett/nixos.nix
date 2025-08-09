{ configVars, osConfig, ... }:
{
  # This file is used for machines without a set hostName, like in AWS for the fedibox where the hostName is dynamic

  imports = [
    ########################## Required Configs ###########################
    common/core # required

    #################### Host-specific Optional Configs ####################
    common/optional/services/ssh-agent.nix
    common/optional/sops.nix
    common/optional/git.nix
  ];

  programs.git.userEmail = configVars.gitHubEmail;

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
