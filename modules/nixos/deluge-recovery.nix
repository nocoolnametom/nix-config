{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.deluge-recovery;

  # Script to backup deluge state when healthy
  backupScript = pkgs.writeShellScript "deluge-backup-state" ''
    set -euo pipefail

    STATE_DIR="/var/lib/deluge/.config/deluge/state"
    BACKUP_DIR="/var/lib/deluge/.config/deluge/state-backups"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)

    # Only backup if deluged is running and responsive
    if ! systemctl is-active --quiet deluged; then
      echo "deluged is not running, skipping backup"
      exit 0
    fi

    # Quick responsiveness check - if daemon responds, it's healthy regardless of CPU
    DAEMON_PORT="${toString config.services.deluge.config.daemon_port}"
    if ! ${pkgs.coreutils}/bin/timeout 3 ${pkgs.bash}/bin/bash -c "echo > /dev/tcp/127.0.0.1/$DAEMON_PORT" 2>/dev/null; then
      echo "deluged is not responding to connections, skipping backup"
      exit 0
    fi

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Keep only last 7 backups
    cd "$BACKUP_DIR"
    ls -t | tail -n +8 | xargs -r rm -rf

    # Create new backup
    BACKUP_PATH="$BACKUP_DIR/backup-$TIMESTAMP"
    mkdir -p "$BACKUP_PATH"

    # Backup state files (not individual .torrent files, those don't corrupt)
    if [ -f "$STATE_DIR/torrents.state" ]; then
      cp "$STATE_DIR/torrents.state" "$BACKUP_PATH/"
    fi
    if [ -f "$STATE_DIR/torrents.fastresume" ]; then
      cp "$STATE_DIR/torrents.fastresume" "$BACKUP_PATH/"
    fi

    echo "Backup created at $BACKUP_PATH"
  '';

  # Script to check if deluged is responsive after startup
  healthCheckScript = pkgs.writeShellScript "deluge-health-check" ''
    set -euo pipefail

    MAX_ATTEMPTS=60  # 60 seconds to become responsive
    ATTEMPT=0
    DAEMON_PORT="${toString config.services.deluge.config.daemon_port}"

    echo "Waiting for deluged to become responsive..."

    # Wait for deluged to start listening on its port
    sleep 5

    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
      # Check if process exists
      if ! ${pkgs.procps}/bin/pgrep -f "deluged-wrapped-wrapped" > /dev/null; then
        echo "deluged process not found, waiting... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
        sleep 1
        ATTEMPT=$((ATTEMPT + 1))
        continue
      fi

      # Test if daemon responds to connections (better than CPU check)
      # A stuck daemon will not respond, a busy daemon will respond quickly
      if ${pkgs.coreutils}/bin/timeout 5 ${pkgs.bash}/bin/bash -c "echo > /dev/tcp/127.0.0.1/$DAEMON_PORT" 2>/dev/null; then
        echo "deluged is accepting connections on port $DAEMON_PORT"

        # Additional check: verify web UI can connect (if enabled)
        if ${pkgs.systemd}/bin/systemctl is-active --quiet delugeweb 2>/dev/null; then
          # Give web UI time to connect to daemon
          sleep 3

          # Test if web API responds (indicates daemon is serving RPC requests)
          if ${pkgs.coreutils}/bin/timeout 5 ${pkgs.curl}/bin/curl -s --max-time 3 \
              "http://localhost:${toString config.services.deluge.web.port}/json" \
              -H "Content-Type: application/json" \
              --data-raw '{"method":"web.connected","params":[],"id":1}' \
              | ${pkgs.gnugrep}/bin/grep -q "result\|error"; then
            echo "deluged is responsive to RPC calls"
            exit 0
          fi
        else
          # If web UI not enabled, just port test is enough
          exit 0
        fi
      fi

      ATTEMPT=$((ATTEMPT + 1))
      echo "Attempt $ATTEMPT: daemon not responding yet, waiting..."
      sleep 1
    done

    echo "ERROR: deluged failed to become responsive after $MAX_ATTEMPTS seconds"
    echo "This indicates a stuck/corrupted state, triggering recovery..."
    exit 1
  '';

  # Script to recover from corrupted state
  recoveryScript = pkgs.writeShellScript "deluge-recovery" ''
    set -euo pipefail

    STATE_DIR="/var/lib/deluge/.config/deluge/state"
    BACKUP_DIR="/var/lib/deluge/.config/deluge/state-backups"
    CORRUPTED_DIR="/var/lib/deluge/.config/deluge/state-corrupted-$(date +%Y%m%d-%H%M%S)"

    echo "=== Deluge Recovery Starting ==="

    # Stop services
    systemctl stop deluged delugeweb || true

    # Move corrupted state aside
    if [ -d "$STATE_DIR" ]; then
      echo "Moving corrupted state to $CORRUPTED_DIR"
      mv "$STATE_DIR" "$CORRUPTED_DIR"
    fi

    # Recreate state directory
    mkdir -p "$STATE_DIR"
    chown deluge:media "$STATE_DIR"
    chmod 755 "$STATE_DIR"

    # Try to restore from latest backup
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR" 2>/dev/null | head -1 || echo "")

    if [ -n "$LATEST_BACKUP" ] && [ -d "$BACKUP_DIR/$LATEST_BACKUP" ]; then
      echo "Attempting to restore from backup: $LATEST_BACKUP"

      # Copy backup state files
      if [ -f "$BACKUP_DIR/$LATEST_BACKUP/torrents.state" ]; then
        cp "$BACKUP_DIR/$LATEST_BACKUP/torrents.state" "$STATE_DIR/"
        chown deluge:media "$STATE_DIR/torrents.state"
      fi

      if [ -f "$BACKUP_DIR/$LATEST_BACKUP/torrents.fastresume" ]; then
        cp "$BACKUP_DIR/$LATEST_BACKUP/torrents.fastresume" "$STATE_DIR/"
        chown deluge:media "$STATE_DIR/torrents.fastresume"
      fi

      # Copy .torrent files from corrupted state
      if [ -d "$CORRUPTED_DIR" ]; then
        echo "Copying .torrent files from corrupted state"
        cp "$CORRUPTED_DIR"/*.torrent "$STATE_DIR/" 2>/dev/null || true
        chown deluge:media "$STATE_DIR"/*.torrent 2>/dev/null || true
      fi

      # Start deluged and check if it works
      systemctl start deluged
      sleep 5

      if ${healthCheckScript}; then
        echo "Recovery successful using backup!"
        systemctl start delugeweb
        exit 0
      else
        echo "Backup restoration failed, falling back to rebuild"
        systemctl stop deluged
      fi
    fi

    # Fallback: Rebuild from scratch
    echo "Rebuilding state from .torrent files"
    rm -f "$STATE_DIR/torrents.state" "$STATE_DIR/torrents.fastresume"

    # Copy .torrent files from corrupted state
    if [ -d "$CORRUPTED_DIR" ]; then
      cp "$CORRUPTED_DIR"/*.torrent "$STATE_DIR/" 2>/dev/null || true
      chown deluge:media "$STATE_DIR"/*.torrent 2>/dev/null || true
    fi

    # Start with clean state
    systemctl start deluged
    sleep 10

    # Re-add all torrents
    echo "Re-adding torrents from .torrent files"
    ADDED=0
    for torrent in "$STATE_DIR"/*.torrent; do
      if [ -f "$torrent" ]; then
        sudo -u deluge deluge-console "connect 127.0.0.1:${toString config.services.deluge.config.daemon_port} localclient; add \"$torrent\"" 2>&1 | grep -v "pkg_resources" || true
        ADDED=$((ADDED + 1))
        sleep 0.2
      fi
    done

    echo "Re-added $ADDED torrents"
    systemctl start delugeweb

    echo "=== Deluge Recovery Complete ==="
  '';

in
{
  options.services.deluge-recovery = {
    enable = lib.mkEnableOption "automatic deluge state backup and recovery";

    backupInterval = lib.mkOption {
      type = lib.types.str;
      default = "hourly";
      description = "How often to backup deluge state (systemd timer format)";
    };

    enableAutoRecovery = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically attempt recovery if deluged fails health check";
    };
  };

  config = lib.mkIf (cfg.enable && config.services.deluge.enable) {
    # Regular backup service
    systemd.services.deluge-state-backup = {
      description = "Backup Deluge State Files";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${backupScript}";
        User = "root";
      };
    };

    # Backup timer
    systemd.timers.deluge-state-backup = {
      description = "Timer for Deluge State Backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.backupInterval;
        Persistent = true;
      };
    };

    # Health check service - automatically runs after deluged starts
    systemd.services.deluge-health-check = lib.mkIf cfg.enableAutoRecovery {
      description = "Check Deluge Daemon Health";
      after = [ "deluged.service" ];
      bindsTo = [ "deluged.service" ];
      wantedBy = [ "deluged.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${healthCheckScript}";
        RemainAfterExit = false;
      };
      # If health check fails, trigger recovery
      onFailure = [ "deluge-recovery.service" ];
    };

    # Recovery service
    systemd.services.deluge-recovery = lib.mkIf cfg.enableAutoRecovery {
      description = "Recover Deluge from Corrupted State";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${recoveryScript}";
        User = "root";
        # Only allow one recovery attempt per hour to avoid loops
        StartLimitBurst = 1;
        StartLimitIntervalSec = 3600;
      };
    };
  };
}
