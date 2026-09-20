###############################################################################
#
#  Feanor - Borg backup + offsite sync
#
#  Direct translation of cirdan's borgmatic.yml. Two independent halves, the
#  same split Synology used:
#
#    1. borg  -> local repo at /silmaril/borg/local.borg
#    2. rclone -> pushes that repo (and two plain directories) to Google Drive
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
in
{
  ############################## Borg ########################################

  sops.secrets."borg/feanor/passphrase" = {
    mode = "0400";
  };

  services.borgbackup.jobs.local = {
    paths = [
      "${pool}/syncthing/Sync/Library/Calibre/Library"
      "${pool}/netbackup"
      "${pool}/jellyfin/Backups"

      # Immich originals. Path assumes the container keeps DSM's
      # upload/{upload,profile,backups} layout under the pool subvolume;
      # confirm against the compose file at migration time.
      "${pool}/immich/upload/upload"
      "${pool}/immich/upload/profile"
      "${pool}/immich/upload/backups"

      # NOTE: cirdan also backed up /volume1/docker/actual. Actual Budget now
      # runs natively on estel (hosts/common/optional/services/actual-budget.nix),
      # so that source looks stale - it should be backed up from estel, not
      # from here. Left out deliberately; re-add if the Docker instance is
      # still authoritative.
    ];

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
  # BLOCKED: needs the `rclone/gdrive-config` secret, which does not exist yet
  # because it requires an interactive OAuth grant. Generate it on a machine
  # with a browser:
  #
  #   rclone config            # n) new remote -> name: gdrive -> type: drive
  #   rclone config show gdrive
  #
  # Paste that whole section (it contains the refresh token) into nix-secrets
  # as `rclone/gdrive-config`, then uncomment below.
  #
  # Strongly recommended: create your own Google Cloud OAuth client ID rather
  # than accepting rclone's built-in one. The shared default is heavily rate
  # limited and you will feel it seeding a repo this size. Google also caps
  # uploads at ~750 GB/day regardless.
  #
  # Mappings carried over from DSM's Cloud Sync tasks:
  #   ${pool}/borg/local.borg                -> gdrive:/borgbackups/feanor
  #   ${pool}/netbackup/FamilyBackup         -> gdrive:/FamilyBackup
  #   ${pool}/jellyfin/TV_Shows/Foreign/Australia/Australian Survivor
  #                                          -> gdrive:/survivor
  #
  # (DSM used /borgbackups/cirdan - renaming to feanor keeps the old archive
  # reachable while the new one seeds. Decide before the first sync runs.)
  #
  # sops.secrets."rclone/gdrive-config" = { mode = "0400"; };
  #
  # systemd.services.rclone-offsite = {
  #   description = "Sync backups and selected media to Google Drive";
  #   after = [ "network-online.target" ];
  #   wants = [ "network-online.target" ];
  #   startAt = "daily";
  #   serviceConfig = {
  #     Type = "oneshot";
  #     IOWeight = 30;
  #     Nice = 15;
  #   };
  #   script =
  #     let
  #       conf = config.sops.secrets."rclone/gdrive-config".path;
  #       rclone = lib.getExe pkgs.rclone;
  #       sync = src: dst: ''
  #         ${rclone} sync --config ${conf} --fast-list --transfers 4 \
  #           --bwlimit 8M "${src}" "gdrive:${dst}"
  #       '';
  #     in
  #     lib.concatStringsSep "\n" [
  #       (sync "${pool}/borg/local.borg" "/borgbackups/feanor")
  #       (sync "${pool}/netbackup/FamilyBackup" "/FamilyBackup")
  #       (sync "${pool}/jellyfin/TV_Shows/Foreign/Australia/Australian Survivor" "/survivor")
  #     ];
  # };

  environment.systemPackages = [
    pkgs.borgbackup
    pkgs.rclone # available now for the interactive `rclone config` run
  ];
}
