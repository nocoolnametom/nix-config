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

    # Sender mode configuration
    (lib.mkIf cfg.sender.enable {
      systemd.services.rsync-cert-sync = {
        description = "Rsync Certificates to VPS";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.writeShellScriptBin "failover-cert-sync" ''
            ${pkgs.rsync}/bin/rsync -az \
              --exclude=acme-challenge \
              --exclude=".*" \
              --chmod=D750,F640 \
              -e "${pkgs.openssh}/bin/ssh -p ${builtins.toString cfg.sender.vpsSshPort} -i ${cfg.sender.sshKeyPath}" \
              ${cfg.sender.localCertPath}/ ${cfg.sender.vpsUser}@${cfg.sender.vpsHost}:${cfg.sender.vpsTargetPath}/
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
    })

    # Receiver mode configuration
    (lib.mkIf cfg.receiver.enable {
      systemd.services.rsync-cert-fix-permissions = {
        description = "Fix Certificate Permissions After Rsync";
        serviceConfig = {
          Type = "oneshot";
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
              # Extract the time portion (assumes format "*-*-* HH:MM:SS")
              parts = lib.splitString " " cfg.receiver.timerSchedule;
              timePart = lib.elemAt parts (lib.length parts - 1);
              timeParts = lib.splitString ":" timePart;
              hour = lib.toInt (lib.elemAt timeParts 0);
              minute = lib.toInt (lib.elemAt timeParts 1);
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
    })
  ];
}
