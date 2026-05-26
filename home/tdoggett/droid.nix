{ configVars, osConfig, ... }:
{
  imports = [
    ########################## Required Configs ###########################
    common/core # required

    #################### Host-specific Optional Configs ####################
    common/optional/services/gpg-agent.nix
    common/optional/services/ssh-agent.nix # standard ssh-agent for SSH (no pinentry needed on headless)
    common/optional/sops.nix
    common/optional/git.nix
    common/optional/claude.nix
  ];

  services.gpg-agent.enableSshSupport = false;

  programs.git.settings.user.email = configVars.gitHubEmail;

  programs.claude.ollamaMachine = configVars.networking.subnets.barliman.name;

  home = {
    stateVersion = "25.11";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
