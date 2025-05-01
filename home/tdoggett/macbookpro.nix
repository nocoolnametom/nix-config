{
  lib,
  config,
  configVars,
  osConfig,
  inputs,
  ...
}:
{
  imports = [
    ########################## Required Configs ###########################
    common/core # required

    #################### Host-specific Optional Configs ####################
    common/optional/sops-work.nix # used instead of sops.nix!
    common/optional/ssh-work.nix
    common/optional/git.nix
    common/optional/devenv.nix
  ];

  programs.git.userEmail = lib.mkForce configVars.email.work;

  home.sessionVariables = {
    TERM = lib.mkForce "xterm-256color";
    TERMINAL = lib.mkForce "";
    GPG_TTY = "${"$"}(tty)";
    SSH_AUTH_SOCK = "${config.home.homeDirectory}/.ssh/agent";
    NVM_DIR = "${config.home.homeDirectory}/.nvm";
    # Secrets defined in secrets flake file
    GITLAB_WORKFLOW_INSTANCE_URL = "https://$(cat ${config.sops.secrets."work/git-server".path})";
    GITLAB_WORKFLOW_TOKEN = "$(cat ${config.sops.secrets."work/git-server-key".path})";
    TELEPORT_LOGIN = "$(cat ${config.sops.secrets."work/brand2-username".path})";
    TELEPORT_PROXY = "teleport.$(cat ${config.sops.secrets."work/brand2-url".path}):443";
    TELEPORT_USER = "$(cat ${config.sops.secrets."work/brand2-username".path})";
    DATABRICKS_HOST = "$(cat ${config.sops.secrets."work/databricks-host".path})";
    DATABRICKS_TOKEN = "$(cat ${config.sops.secrets."work/databricks-token".path})";
    DATABRICKS_SQL_WAREHOUSE_ID = "$(cat ${config.sops.secrets."work/databricks-sql-warehouse-id".path})";
  };

  programs.bash.initExtra = ''
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 
  '';

  programs.zsh.initExtra = ''
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

    # Setting this alias here because the HM way doesn't work with the secret lookup
    alias fub="$(cat ${config.sops.secrets."work/shell-tools-aliases/alias1".path})"
  '';

  home.stateVersion = "24.11";
  home.username = configVars.username;
  home.homeDirectory = lib.mkForce "/Users/${configVars.username}";
}
