{ configVars, osConfig, ... }:
{
  imports = [
    ########################## Required Configs ###########################
    ../common/core # required

    #################### Host-specific Optional Configs ####################
    ../common/optional/services/ssh-agent.nix
    ../common/optional/sops.nix
    ../common/optional/git.nix
  ];

  programs.git.userEmail = configVars.gitHubEmail;

  home = {
    stateVersion = "24.11";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
