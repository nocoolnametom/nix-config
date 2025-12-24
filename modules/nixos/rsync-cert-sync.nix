{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.rsyncCertSync;
in
{
  options.services.rsyncCertSync = {
    sender = {
      enable = lib.mkEnableOption "Send certificates to remote VPS via rsync";

      vpsUser = lib.mkOption {
        type = lib.types.str;
        default = "acme";
        description = "SSH user on the remote VPS.";
      };

      vpsHost = lib.mkOption {
        type = lib.types.str;
        description = "Domain or IP address of the remote VPS.";
      };

      vpsSshPort = lib.mkOption {
        type = lib.types.int;
        default = 22;
        description = "SSH port on the remote VPS.";
      };

      vpsTargetPath = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/acme";
        description = "Remote path on the VPS where certs should be synced.";
      };

      localCertPath = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/acme";
        description = "Local path to the certificates directory to rsync from.";
      };

      sshKeyPath = lib.mkOption {
        type = lib.types.str;
        description = "Private SSH key used for rsync to VPS.";
      };

      timerSchedule = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 03:00:00";
        description = "systemd OnCalendar schedule for syncing certs.";
      };
    };

    receiver = {
      enable = lib.mkEnableOption "Fix certificate permissions after receiving via rsync";

      certPath = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/acme";
        description = "Path to the certificates directory.";
      };

      certUser = lib.mkOption {
        type = lib.types.str;
        default = "acme";
        description = "User ownership for certificates.";
      };

      certGroup = lib.mkOption {
        type = lib.types.str;
        default = "nginx";
        description = "Group ownership for certificates.";
      };

      timerSchedule = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 03:00:00";
        description = "systemd OnCalendar schedule for fixing cert permissions (should match sender schedule).";
      };

      delayMinutes = lib.mkOption {
        type = lib.types.int;
        default = 5;
        description = "Minutes to wait after timerSchedule before running permission fix.";
      };
    };
  };

  config = lib.mkMerge [
    # Common packages
    (lib.mkIf (cfg.sender.enable || cfg.receiver.enable) {
      environment.systemPackages = with pkgs; [
        rsync
        openssh
      ];
    })

    # Sender diagnostic tools
    (lib.mkIf cfg.sender.enable {
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "check-cert-sync-source" ''
          echo "=== Certificate Sync Source Check (estel) ==="
          echo "Certificates available to sync from ${cfg.sender.localCertPath}:"
          echo

          for dir in ${cfg.sender.localCertPath}/*; do
            if [[ ! -d "$dir" ]]; then continue; fi;
            domain=$(basename "$dir")
            if [[ "$domain" == "acme-challenge" ]]; then continue; fi;
            
            echo "📁 $domain"
            if [[ -f "$dir/fullchain.pem" && -f "$dir/key.pem" ]]; then
              size_full=$(du -h "$dir/fullchain.pem" | cut -f1)
              size_key=$(du -h "$dir/key.pem" | cut -f1)
              echo "   ✓ fullchain.pem ($size_full)"
              echo "   ✓ key.pem ($size_key)"
              
              # Show cert info
              ${pkgs.openssl}/bin/openssl x509 -in "$dir/fullchain.pem" -noout -subject -dates 2>/dev/null | while read line; do
                echo "   $line"
              done
            else
              echo "   ✗ INCOMPLETE: Missing cert files"
            fi
            echo
          done

          echo "Total cert directories: $(find ${cfg.sender.localCertPath} -mindepth 1 -maxdepth 1 -type d ! -name acme-challenge | wc -l)"
          echo
          echo "To manually trigger sync, run: sudo systemctl start rsync-cert-sync"
        '')

        (pkgs.writeShellScriptBin "test-cert-sync-dry-run" ''
          echo "=== Dry-run: What WOULD be synced ==="
          echo "From: ${cfg.sender.localCertPath}/"
          echo "To: ${cfg.sender.vpsUser}@${cfg.sender.vpsHost}:${cfg.sender.vpsTargetPath}/"
          echo "Note: Using --delete (removes certs on VPS not present on source)"
          echo
          ${pkgs.rsync}/bin/rsync -avzn \
            --delete \
            --exclude=acme-challenge \
            -e "${pkgs.openssh}/bin/ssh -p ${builtins.toString cfg.sender.vpsSshPort} -i ${cfg.sender.sshKeyPath}" \
            ${cfg.sender.localCertPath}/ ${cfg.sender.vpsUser}@${cfg.sender.vpsHost}:${cfg.sender.vpsTargetPath}/
          echo
          echo "Note: -n flag means this was a dry-run, nothing was actually copied"
        '')
      ];
    })

    # Sender mode configuration
    (lib.mkIf cfg.sender.enable {
      systemd.services.rsync-cert-sync = {
        description = "Rsync Certificates to VPS";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.writeShellScriptBin "failover-cert-sync" ''
            set -e

            echo "[rsync-cert-sync] Starting certificate sync to ${cfg.sender.vpsHost}"
            echo "[rsync-cert-sync] Syncing from ${cfg.sender.localCertPath}/ to ${cfg.sender.vpsUser}@${cfg.sender.vpsHost}:${cfg.sender.vpsTargetPath}/"

            # Strategy: Sync to a separate directory on the VPS (e.g., /var/lib/acme-failover)
            # This allows:
            # - All estel certs to be synced without exclusions
            # - VPS's own ACME-managed certs to remain in /var/lib/acme untouched
            # - Certificate renewals from estel to propagate to the VPS
            # - The entire failover directory to be safely overwritten
            ${pkgs.rsync}/bin/rsync -avz \
              --delete \
              --exclude=acme-challenge \
              --chmod=D750,F640 \
              -e "${pkgs.openssh}/bin/ssh -p ${builtins.toString cfg.sender.vpsSshPort} -i ${cfg.sender.sshKeyPath}" \
              ${cfg.sender.localCertPath}/ ${cfg.sender.vpsUser}@${cfg.sender.vpsHost}:${cfg.sender.vpsTargetPath}/

            echo "[rsync-cert-sync] Sync completed successfully"
          ''}/bin/failover-cert-sync";
          User = "root";
        };
      };

      systemd.timers.rsync-cert-sync = {
        description = "Timer for syncing Certificates to VPS";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.sender.timerSchedule;
          Persistent = true;
        };
      };

      # Watch for certificate changes and trigger sync automatically
      systemd.paths.rsync-cert-sync-on-change = {
        description = "Watch for ACME certificate changes";
        wantedBy = [ "multi-user.target" ];
        pathConfig = {
          PathModified = cfg.sender.localCertPath;
          # Don't trigger too frequently - add a small delay to batch changes
          TriggerLimitIntervalSec = "300s";
          TriggerLimitBurst = 1;
        };
      };
    })

    # Receiver mode configuration
    (lib.mkIf cfg.receiver.enable {
      systemd.services.rsync-cert-fix-permissions = {
        description = "Fix Certificate Permissions After Rsync";
        wantedBy = [ "multi-user.target" ];
        before = [ "nginx.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.writeShellScriptBin "fix-cert-permissions" ''
            # Fix ownership and permissions for all certificates
            ${pkgs.findutils}/bin/find ${cfg.receiver.certPath} -type d -exec ${pkgs.coreutils}/bin/chmod 750 {} \;
            ${pkgs.findutils}/bin/find ${cfg.receiver.certPath} -type f -exec ${pkgs.coreutils}/bin/chmod 640 {} \;
            ${pkgs.coreutils}/bin/chown -R ${cfg.receiver.certUser}:${cfg.receiver.certGroup} ${cfg.receiver.certPath}
          ''}/bin/fix-cert-permissions";
          User = "root";
        };
      };

      systemd.timers.rsync-cert-fix-permissions = {
        description = "Timer for fixing certificate permissions";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.receiver.timerSchedule;
          Persistent = true;
        };
      };

      # Also run the permission fix after a delay from the expected rsync time
      # This ensures permissions are fixed shortly after files are synced
      systemd.timers.rsync-cert-fix-permissions-delayed = {
        description = "Delayed timer for fixing certificate permissions after rsync";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          # Parse the schedule and add the configured delay in minutes
          OnCalendar =
            let
              # Helper to remove leading zeros to avoid octal interpretation
              removeLeadingZeros =
                str:
                let
                  stripped = lib.removePrefix "0" str;
                in
                if stripped == "" then "0" else stripped;

              # Extract the time portion (assumes format "*-*-* HH:MM:SS")
              parts = lib.splitString " " cfg.receiver.timerSchedule;
              timePart = lib.elemAt parts (lib.length parts - 1);
              timeParts = lib.splitString ":" timePart;
              hour = lib.toInt (removeLeadingZeros (lib.elemAt timeParts 0));
              minute = lib.toInt (removeLeadingZeros (lib.elemAt timeParts 1));
              second = lib.elemAt timeParts 2;

              # Add delay minutes
              newMinute = minute + cfg.receiver.delayMinutes;
              finalHour = hour + (newMinute / 60);
              finalMinute = lib.mod newMinute 60;

              # Format back to string
              datePart = lib.concatStringsSep " " (lib.take (lib.length parts - 1) parts);
              hourStr = if finalHour < 10 then "0${toString finalHour}" else toString finalHour;
              minuteStr = if finalMinute < 10 then "0${toString finalMinute}" else toString finalMinute;
            in
            "${datePart} ${hourStr}:${minuteStr}:${second}";
          Persistent = true;
        };
      };

      # Watch for certificate changes and trigger permission fix + failover-redirects regeneration
      systemd.paths.rsync-cert-fix-permissions-on-change = {
        description = "Watch for incoming certificate changes from rsync";
        wantedBy = [ "multi-user.target" ];
        pathConfig = {
          PathModified = cfg.receiver.certPath;
          # Don't trigger too frequently - batch changes together
          TriggerLimitIntervalSec = "60s";
          TriggerLimitBurst = 1;
        };
      };

      # Service to fix permissions and regenerate failover redirects
      systemd.services.rsync-cert-fix-permissions-on-change = {
        description = "Fix permissions and regenerate failover redirects after cert sync";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.writeShellScriptBin "fix-certs-and-regenerate" ''
            # Fix certificate permissions
            ${pkgs.findutils}/bin/find ${cfg.receiver.certPath} -type d -exec ${pkgs.coreutils}/bin/chmod 750 {} \;
            ${pkgs.findutils}/bin/find ${cfg.receiver.certPath} -type f -exec ${pkgs.coreutils}/bin/chmod 640 {} \;
            ${pkgs.coreutils}/bin/chown -R ${cfg.receiver.certUser}:${cfg.receiver.certGroup} ${cfg.receiver.certPath}

            # Trigger failover-redirects regeneration if it exists
            if ${pkgs.systemd}/bin/systemctl list-units --type=service | grep -q failover-redirects-generate; then
              echo "Triggering failover-redirects regeneration..."
              ${pkgs.systemd}/bin/systemctl start failover-redirects-generate.service || true
            fi
          ''}/bin/fix-certs-and-regenerate";
          User = "root";
        };
      };

      # Receiver diagnostic tool
      environment.systemPackages = [
        (pkgs.writeShellScriptBin "check-cert-sync-received" ''
          echo "=== Certificate Sync Receiver Check (bombadil) ==="
          echo "Certificates received in ${cfg.receiver.certPath}:"
          echo

          for dir in ${cfg.receiver.certPath}/*; do
            if [[ ! -d "$dir" ]]; then continue; fi;
            domain=$(basename "$dir")
            if [[ "$domain" == "acme-challenge" ]]; then continue; fi;
            
            # Check if this looks like a synced cert (not locally managed)
            owner=$(stat -c '%U:%G' "$dir" 2>/dev/null || stat -f '%Su:%Sg' "$dir" 2>/dev/null)
            
            echo "📁 $domain (owner: $owner)"
            if [[ -f "$dir/fullchain.pem" && -f "$dir/key.pem" ]]; then
              size_full=$(du -h "$dir/fullchain.pem" | cut -f1)
              size_key=$(du -h "$dir/key.pem" | cut -f1)
              mtime=$(stat -c '%y' "$dir/fullchain.pem" 2>/dev/null || stat -f '%Sm' "$dir/fullchain.pem" 2>/dev/null)
              echo "   ✓ fullchain.pem ($size_full)"
              echo "   ✓ key.pem ($size_key)"
              echo "   Last modified: $mtime"
              
              # Show cert details
              ${pkgs.openssl}/bin/openssl x509 -in "$dir/fullchain.pem" -noout -subject -dates 2>/dev/null | while read line; do
                echo "   $line"
              done
            else
              echo "   ✗ INCOMPLETE: Missing cert files"
            fi
            echo
          done

          echo "Total cert directories: $(find ${cfg.receiver.certPath} -mindepth 1 -maxdepth 1 -type d ! -name acme-challenge | wc -l)"
          echo
          echo "Last rsync-cert-sync run:"
          ${pkgs.systemd}/bin/systemctl status rsync-cert-fix-permissions --no-pager | grep -A5 "Last execution" || echo "  (service not found)"
        '')
      ];
    })
  ];
}
