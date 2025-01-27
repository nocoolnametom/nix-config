{ lib, configVars, ... }:
{
  programs.git.enable = true;
  programs.git.userName = configVars.userFullName;
  programs.git.userEmail = lib.mkDefault configVars.gitHubEmail;
  programs.git.signing.key = "7EC0EE35DDC9D227";
  # I want to figure out how to use nix-secrets and sops to automatically set up my GPG keys!
  programs.git.signing.signByDefault = lib.mkDefault false;
  programs.git.aliases.co = "checkout";
  programs.git.extraConfig = {
    core.editor = "vim";
    log.decorate = "full";
    rebase.autostash = lib.mkDefault true;
    pull.rebase = lib.mkDefault true;
    stash.showPatch = lib.mkDefault true;
    "color \"status\"" = {
      added = "green";
      changed = "yellow bold";
      untracked = "red bold";
    };
  };
}
