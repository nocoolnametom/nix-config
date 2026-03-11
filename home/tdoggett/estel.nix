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
  ];

  # Headless: gpg-agent handles GPG only; standard ssh-agent handles SSH.
  # pinentry-gtk2 requires a display, which estel doesn't have.
  services.gpg-agent.enableSshSupport = false;

  programs.git.settings.user.email = configVars.gitHubEmail;

  home = {
    stateVersion = "25.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
