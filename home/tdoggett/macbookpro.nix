{
  lib,
  pkgs,
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
    common/optional/jj.nix
    common/optional/devenv.nix
    common/optional/claude.nix
    common/optional/docker.nix
    common/optional/docker-darwin.nix
    common/optional/notification-leds.nix
  ];

  programs.claude.enable = true;

  programs.vim = {
    enable = true;
    plugins = [ pkgs.vimPlugins.vim-sensible ];
  };

  programs.git.settings.user.email = lib.mkForce configVars.email.work;
  programs.jujutsu.settings.user.email = lib.mkForce configVars.email.work;

  home.sessionVariables = {
    TERM = lib.mkForce "xterm-256color";
    TERMINAL = lib.mkForce "";
    GPG_TTY = "${"$"}(tty)";
    # Secrets defined in secrets flake file
    GITLAB_WORKFLOW_INSTANCE_URL = "https://$(cat ${config.sops.secrets."work/git-server".path})";
    GITLAB_WORKFLOW_TOKEN = "$(cat ${config.sops.secrets."work/git-server-key".path})";
    GITLAB_API_URL = "https://$(cat ${config.sops.secrets."work/git-server".path})/api/v4";
    GITLAB_PERSONAL_ACCESS_TOKEN = "$(cat ${config.sops.secrets."work/git-server-key".path})";
    TELEPORT_LOGIN = "$(cat ${config.sops.secrets."work/brand2-username".path})";
    TELEPORT_PROXY = "teleport.$(cat ${config.sops.secrets."work/brand2-url".path}):443";
    TELEPORT_USER = "$(cat ${config.sops.secrets."work/brand2-username".path})";
    DATABRICKS_HOST = "$(cat ${config.sops.secrets."work/databricks-host".path})";
    DATABRICKS_TOKEN = "$(cat ${config.sops.secrets."work/databricks-token".path})";
    DATABRICKS_SQL_WAREHOUSE_ID = "$(cat ${
      config.sops.secrets."work/databricks-sql-warehouse-id".path
    })";
  };

  # Login-shell setup: previously a hand-maintained ~/.zprofile.
  # brew shellenv exports PATH/MANPATH/INFOPATH/HOMEBREW_* for the Apple Silicon prefix.
  programs.zsh.profileExtra = ''
    eval "$(${osConfig.homebrew.prefix}/bin/brew shellenv)"
    export PATH="$HOME/.zpm/bin:$PATH"
  '';

  programs.zsh.initContent = ''
    # Setting this alias here because the HM way doesn't work with the secret lookup
    alias fub="$(cat ${config.sops.secrets."work/shell-tools-aliases/alias1".path})"
  '';

  # Regenerate ~/.zcompdump in the background so interactive shells can always
  # use `compinit -C` (~40ms) instead of running a full security-checked compinit
  # (~2.6s). Fires at login and daily at 06:00; if missed, runs on next wake.
  launchd.agents.zsh-compinit-refresh = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.zsh}/bin/zsh"
        "-i"
        "-c"
        "autoload -Uz compinit && compinit"
      ];
      RunAtLoad = true;
      StartCalendarInterval = [
        {
          Hour = 6;
          Minute = 0;
        }
      ];
      StandardOutPath = "/tmp/zsh-compinit-refresh.log";
      StandardErrorPath = "/tmp/zsh-compinit-refresh.log";
    };
  };

  # After each `darwin-rebuild switch`, force the launchd agent to re-run so any
  # newly-installed tools' completions land in ~/.zcompdump immediately rather
  # than waiting for next login or 06:00. Soft-fails if there's no GUI session
  # (e.g. a headless rebuild) — the daily timer will catch up.
  home.activation.refreshZcompdump = lib.hm.dag.entryAfter [ "setupLaunchAgents" ] ''
    /bin/launchctl kickstart -k "gui/$UID/org.nix-community.home.zsh-compinit-refresh" 2>/dev/null || true
  '';

  home.stateVersion = "26.05";
  home.username = configVars.username;
  home.homeDirectory = lib.mkForce "/Users/${configVars.username}";
}
