###############################################################################
#
#  Feanor - Home Manager
#
#  Headless NAS. Deliberately minimal: shell, secrets, version control and
#  nothing that wants a display.
#
###############################################################################

{ configVars, ... }:
{
  imports = [
    ########################## Required Configs ###########################
    common/core # required

    #################### Host-specific Optional Configs ####################
    common/optional/services/atuin.nix
    common/optional/services/gpg-agent.nix
    common/optional/services/ssh-agent.nix # standard ssh-agent (no pinentry on headless)
    common/optional/sops.nix
    common/optional/git.nix
    common/optional/jj.nix
  ];

  programs.atuin.settings.sync_address = "http://${configVars.networking.subnets.estel.ip}:${
    toString configVars.networking.ports.tcp."atuin-sync"
  }";

  # Headless: gpg-agent handles GPG only; standard ssh-agent handles SSH.
  # pinentry-gtk2 requires a display, which feanor doesn't have.
  services.gpg-agent.enableSshSupport = false;

  programs.git.settings.user.email = configVars.gitHubEmail;

  home = {
    stateVersion = "26.05";
    username = configVars.username;
    homeDirectory = "/home/${configVars.username}";
  };
}
