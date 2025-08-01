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
    enable = lib.mkEnableOption "Rsync Certificates to VPS";

    vpsUser = lib.mkOption {
      type = lib.types.str;
      default = "acme";
      description = "SSH user on the VPS.";
    };

    vpsServerGroup = lib.mkOption {
      type = lib.types.str;
      default = "nginx";
      description = "Group ownership of certificates on the VPS.";
    };

    vpsHost = lib.mkOption {
      type = lib.types.str;
      description = "Domain or IP address of the VPS.";
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

  config = lib.mkIf cfg.enable {
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
            --chown=${cfg.vpsUser}:${cfg.vpsServerGroup} --chmod=D750,F640 \
            -e "${pkgs.openssh}/bin/ssh -i ${cfg.sshKeyPath} -o StrictHostKeyChecking=yes" \
            ${cfg.localCertPath}/ ${cfg.vpsUser}@${cfg.vpsHost}:${cfg.vpsTargetPath}/
        ''}/bin/failover-cert-sync";
        User = "root";
      };
    };

    systemd.timers.rsync-cert-sync = {
      description = "Timer for syncing Certificates to VPS";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.timerSchedule;
        Persistent = true;
      };
    };

    environment.systemPackages = with pkgs; [
      rsync
      openssh
    ];
  };
}
