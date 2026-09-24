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
#  SSH key: uses tdoggett's id_ed25519.  That key must be passphrase-free
#  (or stored in ssh-agent) for unattended use.  If the key has a passphrase,
#  generate a dedicated migration key:
#    ssh-keygen -t ed25519 -f /persist/etc/cirdan-sync-key -N ""
#    ssh-copy-id -i /persist/etc/cirdan-sync-key.pub tdoggett@cirdan
#  then point sshKey below at the new key.
#
#  Mount layout on silmaril:
#    /silmaril/jellyfin/            <- cirdan /volume1/Jellyfin/
#    /silmaril/music/               <- cirdan /volume1/Music/
#    /silmaril/comics/              <- cirdan /volume1/Comics/
#    /silmaril/immich/              <- cirdan /volume1/Immich/
#    /silmaril/borg/                <- cirdan /volume1/BorgBackup/
#    /silmaril/netbackup/           <- cirdan /volume1/NetBackup/
#    /silmaril/syncthing/           <- cirdan /volume1/syncthing/
#    /silmaril/cirdan-migration/docker/   <- cirdan /volume1/docker/ (staging)
#    /silmaril/cirdan-migration/family/   <- cirdan /volume1/Family_Data/ (staging)
#
###############################################################################

{ configVars, pkgs, ... }:

let
  sshKey = "/home/${configVars.username}/.ssh/id_ed25519";
  knownHosts = "/home/${configVars.username}/.ssh/known_hosts";

  syncScript = pkgs.writeShellScript "cirdan-sync" ''
    set -euo pipefail

    sync_one() {
      local src="$1" dst="$2"
      echo "=== $(date -Iseconds): starting $src -> $dst ==="
      mkdir -p "$dst"
      ${pkgs.rsync}/bin/rsync \
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
        "$src" "$dst"
      echo "=== $(date -Iseconds): finished $src ==="
    }

    sync_one 'tdoggett@cirdan:/volume1/Jellyfin/'   '/silmaril/jellyfin/'
    sync_one 'tdoggett@cirdan:/volume1/Music/'       '/silmaril/music/'
    sync_one 'tdoggett@cirdan:/volume1/Comics/'      '/silmaril/comics/'
    sync_one 'tdoggett@cirdan:/volume1/Immich/'      '/silmaril/immich/'
    sync_one 'tdoggett@cirdan:/volume1/BorgBackup/'  '/silmaril/borg/'
    sync_one 'tdoggett@cirdan:/volume1/NetBackup/'   '/silmaril/netbackup/'
    sync_one 'tdoggett@cirdan:/volume1/syncthing/'   '/silmaril/syncthing/'
    sync_one 'tdoggett@cirdan:/volume1/docker/'      '/silmaril/cirdan-migration/docker/'
    sync_one 'tdoggett@cirdan:/volume1/Family_Data/' '/silmaril/cirdan-migration/family/'

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
