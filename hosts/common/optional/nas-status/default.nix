###############################################################################
#
#  nas-status - live terminal health dashboard (see nas-status.sh)
#
#  System load, temperatures and fan speeds, network and disk rates, free
#  space, the top services by disk/network/CPU/memory, and the last run of
#  selected jobs. Runs as any user; `sudo nas-status` adds SMART data, btrfs
#  error counters, scrub status and Docker container names.
#
#  The SSH login message points at the command.
#
###############################################################################

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nasStatus;

  nasStatus = pkgs.writeShellApplication {
    name = "nas-status";
    runtimeInputs = with pkgs; [
      btrfs-progs
      coreutils
      gawk
      gnugrep
      gnused
      iproute2
      ncurses # tput
      smartmontools
      systemd
      util-linux # lsblk, mountpoint
    ];
    # The script handles its own errors per section; -e would end the whole
    # dashboard on one missing sensor.
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    text = ''
      export NAS_STATUS_POOL=${lib.escapeShellArg cfg.poolPath}
      export NAS_STATUS_POOL_LABEL=${lib.escapeShellArg cfg.poolLabel}
      export NAS_STATUS_MOUNTS=${lib.escapeShellArg (lib.concatStringsSep " " cfg.mounts)}
      export NAS_STATUS_JOBS=${lib.escapeShellArg (lib.concatStringsSep " " cfg.jobs)}
    ''
    + builtins.readFile ./nas-status.sh;
  };
in
{
  options.services.nasStatus = {
    enable = lib.mkEnableOption "the nas-status terminal dashboard";

    poolPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "/silmaril/jellyfin";
      description = "Any path on the data pool; its filesystem is listed first under STORAGE.";
    };

    poolLabel = lib.mkOption {
      type = lib.types.str;
      default = cfg.poolPath;
      defaultText = lib.literalExpression "config.services.nasStatus.poolPath";
      description = "Name shown for the pool row.";
    };

    mounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/"
        "/nix"
        "/boot"
      ];
      description = "Further mount points to list under STORAGE (same-filesystem ones share a row).";
    };

    jobs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "borgbackup-job-local.service" ];
      description = "Units whose last run (result and time) is shown under JOBS.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ nasStatus ];

    users.motd = lib.mkAfter ''

      ${config.networking.hostName}: live health dashboard (disks, network, temps, fans, busiest services)
        nas-status          sudo nas-status  (adds SMART, btrfs errors, container names)

    '';
  };
}
