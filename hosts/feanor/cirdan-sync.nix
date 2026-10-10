###############################################################################
#
#  cirdan-sync — incremental rsync mirror of the cirdan NAS
#
#  Copies all data shares from cirdan (Synology DSM) to the silmaril btrfs
#  pool on feanor over SSH.  Runs automatically 5 minutes after every boot
#  and again at 03:00 every night, so the initial bulk transfer (expected to
#  take several days at ~44 MB/s) continues across reboots without manual
#  intervention.
#
#  Design decisions:
#    - bwlimit=44000 KB/s: half the measured 86 MB/s peak.  Leaves headroom
#      for other LAN traffic and Jellyfin streaming during the migration.
#    - --append-verify: on restart, only the missing tail of large files is
#      re-sent; the existing portion is checksum-verified before appending.
#    - --partial: aborted transfers are kept as partial files rather than
#      deleted, so the next run can resume from where it stopped.
#    - --no-delete: intentional.  This is a one-way COPY, not a mirror.
#      Files deleted on cirdan are NOT deleted on feanor, preserving anything
#      already copied even if cirdan's data changes mid-migration.
#    - One service instance at a time: systemd ignores a timer that fires
#      while the previous run is still going.  The first run will be active
#      for days; subsequent nightly runs top up whatever changed that day.
#
#  SSH key: uses a dedicated passphrase-free key at /persist/etc/cirdan-sync-key
#  (in /persist so it survives the ephemeral root wipe on every boot).
#  Generate it once:
#    sudo ssh-keygen -t ed25519 -f /persist/etc/cirdan-sync-key -N ""
#    ssh-copy-id -i /persist/etc/cirdan-sync-key.pub <username>@cirdan
#
#  Mount layout on silmaril:
#    /silmaril/jellyfin/            <- (no longer synced; feanor is authoritative
#                                       since the 2026-10-05 Sonarr/Radarr cutover)
#    /silmaril/music/               <- (no longer synced; nothing writes music to cirdan)
#    /silmaril/comics/              <- cirdan /volume1/Comics/
#    /silmaril/immich/              <- (no longer synced; Immich runs on feanor)
#    /silmaril/borg/                <- (no longer synced; feanor's borg job owns it)
#    /silmaril/netbackup/           <- (no longer synced; feanor's WebDAV is the target)
#    /silmaril/syncthing/           <- (now via Syncthing, not rsync)
#    /silmaril/tubearchivist/media/ <- (no longer synced; the USB disk itself moved
#                                       to feanor on 2026-10-10)
#    /silmaril/cirdan-migration/docker/   <- cirdan /volume1/docker/ (staging)
#    /silmaril/cirdan-migration/family/   <- cirdan /volume1/Family_Data/ (staging)
#
###############################################################################

{ configVars, pkgs, ... }:

let
  # Passphrase-free key stored in /persist so it survives the ephemeral root
  # wipe on every boot.  Generate it once with:
  #   sudo ssh-keygen -t ed25519 -f /persist/etc/cirdan-sync-key -N ""
  # then add the .pub to cirdan's authorized_keys via ssh-copy-id.
  sshKey = "/persist/etc/cirdan-sync-key";
  knownHosts = "/home/${configVars.username}/.ssh/known_hosts";

  syncScript = pkgs.writeShellScript "cirdan-sync" ''
    set -uo pipefail

    # One unreadable path must not stop the remaining shares (with set -e it
    # did: authentik's DB files aborted every run before Family_Data). Each
    # share runs regardless; the unit still fails at the end if any did, so
    # the failure alert keeps firing.
    failed=()

    sync_one() {
      local src="$1" dst="$2"
      shift 2
      echo "=== $(date -Iseconds): starting $src -> $dst ==="
      mkdir -p "$dst"
      ${pkgs.rsync}/bin/rsync "$@" \
        --archive \
        --partial \
        --append-verify \
        --stats \
        --human-readable \
        --bwlimit=44000 \
        --exclude='@eaDir' \
        --exclude='#recycle' \
        --exclude='@tmp' \
        --exclude='.DS_Store' \
        -e "${pkgs.openssh}/bin/ssh -i ${sshKey} -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${knownHosts} -o BatchMode=yes" \
        "$src" "$dst" || { failed+=("$src"); echo "!!! $src failed" >&2; }
      echo "=== $(date -Iseconds): finished $src ==="
    }

    # Removed 2026-10-05, now authoritative on feanor (syncing from cirdan could
    # only bring back stale or deleted files): Jellyfin (Sonarr/Radarr write to
    # feanor), Immich (runs on feanor), Music (nothing writes it to cirdan).
    sync_one '${configVars.username}@cirdan:/volume1/Comics/'      '/silmaril/comics/'
    # BorgBackup removed 2026-10-05: feanor's borg job now writes its own copy of
    # this repository (same repository id), and cirdan's borgmatic is off.
    # Copying cirdan's files over it would mix two diverged histories.
    # NetBackup removed 2026-10-05: GrapheneOS/Seedvault now writes to feanor's
    # WebDAV directly (webdav.<homeDomain>/NetBackup -> /silmaril/netbackup).
    # /volume1/syncthing/ is no longer rsynced: since 2026-10-03 feanor is a
    # Syncthing peer of cirdan for all of those folders, and rsync writing into
    # Syncthing-managed folders would show up as local changes / conflicts.
    # Skipped: database directories this login cannot read, none of which are
    # needed - authentik/ retires with cirdan, immich was restored from its own
    # SQL dump, podfetch started fresh, standardnotes stays with Proton.
    sync_one '${configVars.username}@cirdan:/volume1/docker/'      '/silmaril/cirdan-migration/docker/' \
      --exclude='/authentik/' --exclude='/immich/db/' --exclude='/podfetch/db/' --exclude='/standardnotes/'
    # TubeArchivist removed 2026-10-10: the USB disk that held this media was
    # physically moved out of cirdan's cabinet and attached to feanor, so
    # cirdan:/volumeUSB2 no longer exists and every run failed on it. The
    # 286 GB of media was already copied to /silmaril/tubearchivist/media.
    # (docker/tubearchivist on cirdan was only ever a symlink to that disk, so
    # the /volume1/docker/ sync above copied the link, not the contents.)
    sync_one '${configVars.username}@cirdan:/volume1/Family_Data/' '/silmaril/cirdan-migration/family/'

    if [ "''${#failed[@]}" -gt 0 ]; then
      echo "=== $(date -Iseconds): finished with failures: ''${failed[*]} ===" >&2
      exit 1
    fi
    echo "=== $(date -Iseconds): all syncs complete ==="
  '';
in

{
  systemd.services.cirdan-sync = {
    description = "Incremental rsync of cirdan NAS data to silmaril pool";

    # Data pool must be mounted and network must be up before we transfer.
    after = [
      "local-fs.target"
      "network-online.target"
      "nss-lookup.target"
    ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = syncScript;
      User = "root";

      # Never auto-restart: the timer handles re-scheduling.
      Restart = "no";

      # The initial bulk transfer will take days.  No timeout.
      TimeoutStartSec = 0;

      # On stop/reboot, give rsync time to finish writing the current chunk
      # cleanly before killing it.  --partial means any aborted file is kept,
      # so the next run can resume without re-sending from the start.
      TimeoutStopSec = "5min";
    };
  };

  systemd.timers.cirdan-sync = {
    description = "Timer for incremental cirdan -> silmaril data migration";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      # Fire 5 minutes after boot so the network stabilises and all silmaril
      # subvolumes are mounted before rsync touches them.
      OnBootSec = "5min";

      # Also run every night at 03:00 to top up anything that changed on
      # cirdan during the day.  After the bulk phase finishes this keeps
      # feanor in sync until cirdan is retired.
      OnCalendar = "*-*-* 03:00:00";

      # If a scheduled run was missed (machine was off), fire as soon as the
      # machine next comes up rather than silently skipping it.
      Persistent = true;

      # One instance at a time.  If the previous run is still active (it will
      # be for the first several days), systemd ignores this trigger rather
      # than stacking a second instance.
      Unit = "cirdan-sync.service";
    };
  };
}
