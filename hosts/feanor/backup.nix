###############################################################################
#
#  Feanor - Borg backup + offsite sync
#
#  Direct translation of cirdan's borgmatic.yml. Two independent halves, the
#  same split Synology used:
#
#    1. borg  -> local repo at /silmaril/borg/local.borg
#    2. rclone -> pushes that repo, the Seedvault phone backups and
#                 FamilyBackup to Google Drive
#
#  Borg cannot write to Google Drive itself - it needs POSIX semantics or a
#  `borg serve` SSH endpoint - which is exactly why DSM ran Cloud Sync as a
#  separate job. Keeping that shape means the existing archive history stays
#  valid: rclone the repo down, point this job at it, keep appending.
#
#  NOTE: the borgmatic file also carried `ssh_command: ssh -i .../id_synology`.
#  That is vestigial with a local repo path - borg only consults it for remote
#  repositories - so no key is needed here.
#
###############################################################################

{
  config,
  lib,
  pkgs,
  configVars,
  ...
}:

let
  pool = "/silmaril";
  repo = "${pool}/borg/local.borg";

  # Needs `rclone/gdrive/full-config` in nix-secrets (see Offsite below).
  offsiteEnabled = true;
in
{
  ############################## Borg ########################################

  sops.secrets."borg/feanor/passphrase" = {
    mode = "0400";
  };

  # failOnWarnings is on, and borg warns on a missing source path. The
  # snapshot repository only appears with TA's first snapshot, so make sure it
  # always exists (owned like the rest of the ES data: 1000:0).
  systemd.tmpfiles.rules = [
    "d /var/lib/tubearchivist/es/snapshot 0770 1000 0 -"
  ];

  # Logical dumps are what borg should hold for databases: a copy of the live
  # data directory taken mid-write may not be restorable.
  services.postgresqlBackup = {
    enable = true;
    databases = [ "podfetch" ];
    startAt = "*-*-* 01:30:00"; # before borg's daily run
  };

  services.borgbackup.jobs.local = {
    paths = [
      "${pool}/syncthing/Sync/Library/Calibre/Library"
      "${pool}/netbackup" # FamilyBackup etc.; Seedvault is excluded below
      "${pool}/jellyfin/Backups"

      # Immich originals, under services.immich.mediaLocation (default.nix).
      # backups/ holds Immich's own nightly database dumps.
      "${pool}/immich/upload/upload"
      "${pool}/immich/upload/profile"
      "${pool}/immich/upload/backups"

      # TubeArchivist's Elasticsearch snapshots (Settings > Application >
      # Snapshots; TA recommends these over its old zip backups). ES is TA's
      # primary store; restorable into any ES 8.x via the snapshot API.
      "/var/lib/tubearchivist/es/snapshot"

      # Kanidm's nightly online backups (22:00): users, credentials, passkeys,
      # OAuth2 clients. Restorable with `kanidmd database restore`.
      "/var/lib/kanidm/backups"

      # Nightly pg_dump of databases without their own dump job (see
      # services.postgresqlBackup below). Immich dumps itself into upload/backups.
      config.services.postgresqlBackup.location

      # Small app state that lives only on this host:
      "/var/lib/autocaliweb/config" # app.db (users, shelves, progress), acw.db
      "/var/lib/redis-tubearchivist" # TubeArchivist's app settings (dump.rdb)
      # Navidrome's own nightly database backups.
      "/var/lib/navidrome/backups"
      # Audiobookshelf's own scheduled backups (database + metadata).
      "/var/lib/audiobookshelf/metadata/backups"
      # Kavita's own nightly backups: database, covers, bookmarks, themes,
      # appsettings. Taken by Kavita itself, so the database copy is consistent.
      "/var/lib/kavita/config/backups"
      "/var/lib/kavitan/config/backups"

      # NOTE: cirdan also backed up /volume1/docker/actual. Actual Budget now
      # runs natively on estel (hosts/common/optional/services/actual-budget.nix),
      # so that source looks stale - it should be backed up from estel, not
      # from here. Left out deliberately; re-add if the Docker instance is
      # still authoritative.
    ];

    # Seedvault's phone backups are already encrypted, versioned snapshots, so
    # borg cannot deduplicate them: every phone backup was stored again in
    # full, ~2/3 of the repository. They reach Google Drive through rclone
    # directly instead (see Offsite below).
    exclude = [ "${pool}/netbackup/.SeedVaultAndroidBackup" ];

    repo = repo;

    encryption = {
      mode = "repokey-blake2";
      passCommand = "cat ${config.sops.secrets."borg/feanor/passphrase".path}";
    };

    compression = "zstd";
    startAt = "daily";

    # Matches borgmatic's keep_daily/weekly/monthly/yearly exactly.
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 6;
      yearly = 2;
    };

    # borgmatic ran `checks: - name: repository`; this is the equivalent and
    # runs after each prune.
    postPrune = ''
      borg check --repository-only "$BORG_REPO"
    '';

    # Bulk archival work must never outrank a Jellyfin stream. See
    # hosts/common/optional/io-latency-tuning.nix.
    extraCreateArgs = [ "--stats" ];
  };

  systemd.services."borgbackup-job-local".serviceConfig = {
    IOWeight = 30;
    Nice = 10;
  };

  ############################ Offsite (rclone) ##############################
  #
  # Switched by `offsiteEnabled` (top of this file). The config secret
  # `rclone/gdrive/full-config` came from an interactive OAuth grant on a
  # machine with a browser (with our own client id/secret, also kept in
  # nix-secrets as rclone/gdrive/client_{id,secret}):
  #
  #   rclone config            # n) new remote -> name: gdrive -> type: drive
  #                            #    scope: 1 (full drive), so rclone can see
  #                            #    the folders DSM's Cloud Sync uploaded
  #   rclone config show gdrive
  #
  # That whole section (it contains the refresh token) is the secret; rerun the
  # same steps if the token is ever revoked.
  #
  # Strongly recommended: your own Google Cloud OAuth client ID instead of
  # rclone's built-in one, which is heavily rate limited. Google also caps
  # uploads at ~750 GB/day.
  #
  # What goes where:
  #   ${pool}/borg/local.borg                    -> gdrive:/borgbackups/feanor
  #   ${pool}/netbackup/.SeedVaultAndroidBackup  -> gdrive:/SeedVaultAndroidBackup
  #   ${pool}/netbackup/FamilyBackup             -> gdrive:/FamilyBackup
  # Seedvault skips borg (see `exclude` above) and is copied as-is: it is
  # already encrypted and keeps its own versions.
  #
  # DSM's old upload (gdrive:/borgbackups/cirdan, ~92 GB with Seedvault) was
  # deleted 2026-10-06 after the first feanor copy checked out.
  #
  # Checking the Drive copy: `borg with-lock` commits a no-op transaction when
  # it releases the lock, so the local repository always has one more tiny
  # commit (hints/index/integrity.N plus a data segment) than Drive. An
  # `rclone check` reporting only those as missing, with no "md5 differ", is
  # a good copy; borg restores the Drive copy at its last real commit.
  sops.secrets."rclone/gdrive/full-config" = lib.mkIf offsiteEnabled { mode = "0400"; };

  systemd.services.rclone-offsite = lib.mkIf offsiteEnabled {
    description = "Copy backups to Google Drive";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # After the midnight borg run and the phone's early-morning Seedvault run.
    startAt = "*-*-* 06:00:00";
    environment.BORG_PASSCOMMAND = "cat ${config.sops.secrets."borg/feanor/passphrase".path}";
    serviceConfig = {
      Type = "oneshot";
      # rclone rewrites its config when it refreshes the OAuth token, and the
      # sops file is read-only, so it works on a private copy.
      RuntimeDirectory = "rclone-offsite";
      RuntimeDirectoryMode = "0700";
      IOWeight = 30;
      Nice = 15;
    };
    script =
      let
        rclone = lib.getExe pkgs.rclone;
        conf = "/run/rclone-offsite/rclone.conf"; # inside RuntimeDirectory
        # --checksum: Drive keeps MD5s, so unchanged files are skipped by
        # content, not timestamps. --drive-use-trash=false: borg compaction
        # deletes old segments, and trashed files still count against quota.
        sync =
          src: dst:
          lib.escapeShellArgs [
            rclone
            "sync"
            "--config=${conf}"
            "--fast-list"
            "--checksum"
            "--transfers=4"
            "--bwlimit=8M"
            "--drive-use-trash=false"
            # with-lock itself creates these; a restored copy must not carry them
            "--exclude=/lock.exclusive/**"
            "--exclude=/lock.roster"
            src
            "gdrive:${dst}"
          ];
      in
      ''
        install -m 0600 ${config.sops.secrets."rclone/gdrive/full-config".path} ${conf}

        # Hold borg's lock for the upload so no backup or prune changes the
        # repository halfway through (a mixed copy may not be restorable).
        ${lib.getExe pkgs.borgbackup} with-lock --lock-wait 7200 ${repo} ${sync repo "/borgbackups/feanor"}
        ${sync "${pool}/netbackup/.SeedVaultAndroidBackup" "/SeedVaultAndroidBackup"}
        ${sync "${pool}/netbackup/FamilyBackup" "/FamilyBackup"}
      '';
  };

  environment.systemPackages = [
    pkgs.borgbackup
    pkgs.rclone # available now for the interactive `rclone config` run
  ];
}
