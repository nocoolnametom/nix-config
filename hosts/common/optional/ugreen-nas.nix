###############################################################################
#
#  UGREEN NASync hardware support
#
#  Fan control, drive LEDs, SMART monitoring and spindown for UGREEN DXP-series
#  NAS units. Tested against the DXP4800 Plus; the it87 chip id may differ on
#  other models in the line.
#
#  BIOS PREREQUISITE (not something NixOS can do for you):
#  The board runs a watchdog that expects UGOS to check in and hard-reboots
#  after ~180 seconds otherwise. Disable it in BIOS (Ctrl+F12 at POST, some
#  units use Del) BEFORE attempting an install, or the installer will be
#  killed partway through.
#
###############################################################################

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.ugreenNas;
in
{
  options.hardware.ugreenNas = {
    enable = lib.mkEnableOption "UGREEN NASync fan, LED and disk management";

    it87ForceId = lib.mkOption {
      type = lib.types.str;
      default = "0x8613";
      description = ''
        Chip id forced onto the out-of-tree it87 driver. The DXP4800 Plus uses
        an ITE IT8613E, which mainline hwmon does not recognise on its own.
      '';
    };

    diskSpindownSeconds = lib.mkOption {
      type = lib.types.int;
      default = 1200; # 20 minutes
      description = ''
        Idle time before spinning down spinning rust. Set to 0 to disable.
        Only applied to rotational devices - NVMe and SSDs are skipped.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    ###########################################################################
    # Fan control
    #
    # Out-of-tree it87 driver; nixpkgs ships it as linuxPackages.it87 so it is
    # rebuilt automatically against whichever kernel the host ends up on.
    ###########################################################################

    boot.extraModulePackages = [ config.boot.kernelPackages.it87 ];
    boot.kernelModules = [ "it87" ];
    boot.extraModprobeConfig = ''
      options it87 ignore_resource_conflict=1 force_id=${cfg.it87ForceId}
    '';

    environment.systemPackages = [
      pkgs.lm_sensors
      pkgs.smartmontools
      pkgs.hdparm
      pkgs.ugreen-leds-cli # front-panel and per-bay drive LEDs
    ];

    ###########################################################################
    # SMART monitoring
    #
    # These are 20 TB+ drives holding data that is expensive to re-acquire.
    # Short test nightly, long test weekly, shout early on temperature.
    ###########################################################################

    services.smartd = {
      enable = true;
      autodetect = true;
      defaults.monitored = "-a -o on -S on -s (S/../.././02|L/../../6/03) -W 4,45,55";
    };

    ###########################################################################
    # Disk spindown
    #
    # Rotational drives only. A NAS that is idle most of the day has no reason
    # to keep four 20 TB drives spinning.
    ###########################################################################

    services.udev.extraRules = lib.mkIf (cfg.diskSpindownSeconds > 0) (
      let
        # hdparm -S encoding: 1..240 == value * 5 seconds.
        spindownValue = toString (lib.min 240 (lib.max 1 (cfg.diskSpindownSeconds / 5)));
      in
      ''
        ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", \
          RUN+="${pkgs.hdparm}/bin/hdparm -S ${spindownValue} -B 127 /dev/%k"
      ''
    );

    # The board's watchdog is disabled in BIOS (see header). NixOS leaves
    # systemd's runtime watchdog off by default, so there is nothing to undo
    # here - just don't turn on systemd.settings.Manager.RuntimeWatchdogSec
    # for these machines.
  };
}
