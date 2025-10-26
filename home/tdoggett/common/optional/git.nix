{ lib, configVars, ... }:
{
  programs.git.enable = true;
  programs.git.settings.user.name = configVars.userFullName;
  programs.git.settings.user.email = lib.mkDefault configVars.gitHubEmail;
  programs.git.signing.key = "7EC0EE35DDC9D227";
  # I want to figure out how to use nix-secrets and sops to automatically set up my GPG keys!
  programs.git.signing.signByDefault = lib.mkDefault false;
  programs.git.settings.alias.co = "checkout";
  programs.git.settings.core.editor = "vim";
  programs.git.settings.log.decorate = "full";
  programs.git.settings.rebase.autostash = lib.mkDefault true;
  programs.git.settings.pull.rebase = lib.mkDefault true;
  programs.git.settings.stash.showPatch = lib.mkDefault true;
  programs.git.settings."color \"status\"" = {
    added = "green";
    changed = "yellow bold";
    untracked = "red bold";
  };
}
