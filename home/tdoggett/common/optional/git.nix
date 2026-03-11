{
  lib,
  pkgs,
  config,
  configLib,
  configVars,
  ...
}:
{
  home.packages = [ pkgs.diff-so-fancy ];

  programs.git.enable = true;

  # User identity
  programs.git.settings.user.name = configVars.userFullName;
  programs.git.settings.user.email = lib.mkDefault configVars.gitHubEmail;

  # Per-remote-host email and signing key overrides (requires git 2.36+).
  # Each domain maps to three URL forms: HTTPS, explicit git@, and bare host:
  # (bare host arises when SSH config sets User=git, so git@ is omitted).
  # NOTE: git uses WM_PATHNAME wildmatch for hasconfig URL patterns, so ** is only
  # "match across path separators" in the forms /**/ (middle), **/ (start), or /**
  # (end after /). After a colon, ** behaves like * and won't cross /. Use */** so
  # that * matches the first path component and /** matches the rest.
  programs.git.includes =
    let
      domainEmailMap = {
        "github.com" = configVars.gitHubEmail;
        "gitlab.com" = configVars.gitLabEmail;
        "${configVars.work.urls.repoDomain}" = configVars.email.work;
      };
    in
    lib.concatMap (
      domain:
      map
        (url: {
          condition = "hasconfig:remote.*.url:${url}";
          contents.user.email = domainEmailMap.${domain};
        })
        [
          "https://${domain}/**"
          "git@${domain}:*/**"
          "${domain}:*/**"
        ]
    ) (lib.attrNames domainEmailMap);

  # Signing — SSH key signing; id_yubikey only exists while a Yubikey is plugged in.
  # Signing will fail silently on commits where signByDefault is true and no key is present.
  programs.git.settings.gpg.format = "ssh";
  programs.git.settings.user.signingKey = lib.mkDefault "~/.ssh/id_yubikey";
  programs.git.settings.commit.gpgSign = lib.mkDefault true;
  programs.git.settings."gpg \"ssh\"".allowedSignersFile =
    "${config.home.homeDirectory}/.config/git/allowed_signers";

  # Generate allowed_signers from all public keys in the repo, mapped to all commit emails.
  # id_nixbuilder is excluded — it's for remote builds only, never used for signing.
  home.file.".config/git/allowed_signers".text =
    let
      keyDir = configLib.relativeToRoot "hosts/common/users/${configVars.username}/keys";
      excludedKeys = [ "id_nixbuilder" ];
      keyFiles = builtins.filter (
        f: lib.hasSuffix ".pub" f && !(builtins.elem (lib.removeSuffix ".pub" f) excludedKeys)
      ) (builtins.attrNames (builtins.readDir keyDir));
      principals = lib.concatStringsSep "," [
        configVars.gitHubEmail
        configVars.gitLabEmail
        configVars.email.work
      ];
    in
    lib.concatMapStringsSep "\n" (f: "${principals} ${lib.fileContents "${keyDir}/${f}"}") keyFiles;

  # Core
  programs.git.settings.core.editor = "vim";
  programs.git.settings.core.pager = "diff-so-fancy | less --tabs=4 -RFX";
  programs.git.settings.core.compression = 9;
  programs.git.settings.core.whitespace = "trailing-space,space-before-tab,cr-at-eol";

  # Commit
  programs.git.settings.commit.verbose = true;

  # Diff
  programs.git.settings.diff.algorithm = "histogram";

  # Branch
  programs.git.settings.branch.sort = "-committerdate";

  # Column
  programs.git.settings.column.ui = "auto";

  # Tag
  programs.git.settings.tag.sort = "version:refname";

  # Pull
  programs.git.settings.pull.rebase = lib.mkDefault true;

  # Push
  programs.git.settings.push.autoSetupRemote = true;
  programs.git.settings.push.useForceIfIncludes = true;

  # Rebase
  programs.git.settings.rebase.autostash = lib.mkDefault true;

  # Maintenance
  programs.git.settings.maintenance.auto = true;
  programs.git.settings.maintenance.strategy = "incremental";

  # Log
  programs.git.settings.log.decorate = "full";

  # Status
  programs.git.settings.status.branch = true;

  # Stash
  programs.git.settings.stash.showPatch = lib.mkDefault true;

  # Rerere
  programs.git.settings.rerere.enabled = true;
  programs.git.settings.rerere.autoupdate = true;

  # Help
  programs.git.settings.help.autocorrect = "prompt";

  # Aliases
  programs.git.settings.alias.co = "checkout";
  programs.git.settings.alias.force = "push --force-with-lease";
  programs.git.settings.alias.graph = "log --all --graph --decorate --oneline";

  # Colors
  programs.git.settings."color \"status\"" = {
    added = "green";
    changed = "yellow bold";
    untracked = "red bold";
  };
}
