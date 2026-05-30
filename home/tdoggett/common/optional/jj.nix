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
  # subprocess = true makes jj invoke the `git` CLI for fetch/push so git hooks
  # (pre-push etc.) actually fire. Default in jj 0.41 uses libgit2 directly,
  # which bypasses all hooks.
  programs.jujutsu.settings.git.subprocess = true;

  # Signing — SSH key signing, sharing git.nix's allowed_signers file.
  # behavior = "keep" means jj won't sign during normal work (no YubiKey touches
  # on every snapshot/rewrite) but preserves existing signatures from coworkers.
  # Combined with git.sign-on-push, signing happens once per commit at push time.
  programs.jujutsu.settings.signing.backend = "ssh";
  programs.jujutsu.settings.signing.key = lib.mkDefault "~/.ssh/id_yubikey";
  programs.jujutsu.settings.signing.behavior = lib.mkDefault "keep";
  programs.jujutsu.settings.signing.backends.ssh.allowed-signers =
    "${config.home.homeDirectory}/.config/git/allowed_signers";
  programs.jujutsu.settings.git.sign-on-push = true;

  # Revsets — what `jj log` shows by default
  programs.jujutsu.settings.revsets.log =
    "present(@) | ancestors(immutable_heads().., 2) | present(trunk())";

  # Aliases
  programs.jujutsu.settings.aliases.l = [ "log" ];
  programs.jujutsu.settings.aliases.s = [ "status" ];
  programs.jujutsu.settings.aliases.d = [ "diff" ];
  programs.jujutsu.settings.aliases.graph = [
    "log"
    "-r"
    "all()"
  ];
}
