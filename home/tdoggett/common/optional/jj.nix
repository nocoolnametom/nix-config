{
  lib,
  pkgs,
  config,
  configLib,
  configVars,
  ...
}:
{
  programs.jujutsu.enable = true;

  # User identity
  programs.jujutsu.settings.user.name = configVars.userFullName;
  programs.jujutsu.settings.user.email = lib.mkDefault configVars.gitHubEmail;

  # UI
  programs.jujutsu.settings.ui.default-command = "log";
  programs.jujutsu.settings.ui.editor = "vim";
  programs.jujutsu.settings.ui.diff.format = "color-words";

  # Git backend behavior
  # auto-local-bookmark = false keeps `jj git fetch` from creating a local
  # bookmark for every remote branch. Recommended jj default.
  programs.jujutsu.settings.git.auto-local-bookmark = false;

  # Signing — SSH key signing, sharing git.nix's allowed_signers file.
  # behavior = "own" signs commits authored by the configured user.email.
  programs.jujutsu.settings.signing.backend = "ssh";
  programs.jujutsu.settings.signing.key = lib.mkDefault "~/.ssh/id_yubikey";
  programs.jujutsu.settings.signing.behavior = lib.mkDefault "own";
  programs.jujutsu.settings.signing.backends.ssh.allowed-signers =
    "${config.home.homeDirectory}/.config/git/allowed_signers";

  # Revsets — what `jj log` shows by default
  programs.jujutsu.settings.revsets.log = "present(@) | ancestors(immutable_heads().., 2) | present(trunk())";

  # Aliases
  programs.jujutsu.settings.aliases.l = [ "log" ];
  programs.jujutsu.settings.aliases.s = [ "status" ];
  programs.jujutsu.settings.aliases.d = [ "diff" ];
  programs.jujutsu.settings.aliases.graph = [ "log" "-r" "all()" ];
}
