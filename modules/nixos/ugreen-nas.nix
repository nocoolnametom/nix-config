###############################################################################
#
#  hardware.ugreenNas — UGREEN NASync hardware support
#
#  A self-contained NixOS module for UGREEN DX/DXP series NAS units running
#  non-UGOS Linux.  Covers:
#
#    • IT8613E fan controller (out-of-tree it87 driver)
#    • Front-panel LED control via the led-ugreen kernel module
#        – ugreen-probe-leds  oneshot: registers the I2C device at boot
#        – ugreen-diskiomon   daemon:  blinks bay LEDs on disk I/O / health
#        – ugreen-netdevmon   daemon:  colours the network LED by link state
#    • SMART monitoring (smartd)
#    • Rotational-disk spindown (hdparm via udev)
#
#  All behaviour is disabled by default; enable what you need explicitly.
#
#  Minimal usage (boot animation silenced, LEDs static):
#
#    hardware.ugreenNas.enable = true;
#    hardware.ugreenNas.leds.enable = true;
#
#  Full usage (live activity LEDs):
#
#    hardware.ugreenNas = {
#      enable = true;
#      leds = {
#        enable = true;
#        diskiomon.enable = true;
#        netdevmon = { enable = true; interface = "enp2s0"; };
#      };
#    };
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
  ledsCfg = cfg.leds;

  # RGB option type: accepts "R G B" strings such as "255 255 255"
  rgbType = lib.types.strMatching "[0-9]+ [0-9]+ [0-9]+";

  # Whether to start the diskiomon and/or netdevmon daemons.  Both require
  # the led-ugreen kernel module AND ugreen-probe-leds to have run first.
  runDiskiomon = ledsCfg.enable && ledsCfg.diskiomon.enable;
  runNetdevmon = ledsCfg.enable && ledsCfg.netdevmon.enable;

  # Spindown hdparm -S value: 1–240 means (value * 5) seconds.
  spindownHdparmValue = toString (lib.min 240 (lib.max 1 (cfg.spindown.idleSeconds / 5)));

  # Resolve the config file path for a daemon (or "" when none is set).
  resolveConf = cfgFile: if cfgFile != null then toString cfgFile else "/etc/ugreen-leds.conf";

in
{
  #############################################################################
  # Options
  #############################################################################

  options.hardware.ugreenNas = {

    enable = lib.mkEnableOption "UGREEN NASync hardware support (DX/DXP series)";

    # ── IT8613E fan controller ───────────────────────────────────────────────

    it87 = {
      enable = lib.mkEnableOption "IT8613E fan controller via out-of-tree it87 driver" // {
        default = true;
      };

      forceId = lib.mkOption {
        type = lib.types.str;
        default = "0x8613";
        example = "0x8620";
        description = ''
          Chip ID passed to the it87 driver via modprobe options.  The DXP4800
          Plus uses an ITE IT8613E which the mainline hwmon driver does not
          recognise without the override.
        '';
      };
    };

    # ── SMART monitoring ─────────────────────────────────────────────────────

    smart = {
      enable = lib.mkEnableOption "SMART disk health monitoring via smartd" // {
        default = true;
      };

      monitoringDefaults = lib.mkOption {
        type = lib.types.str;
        # Short self-test nightly at 02:00, long test Saturdays at 03:00.
        # -W 4,45,55: warn at 45 °C, critical at 55 °C, alert on 4 °C rise.
        default = "-a -o on -S on -s (S/../.././02|L/../../6/03) -W 4,45,55";
        description = ''
          smartd monitoring directives applied to every auto-detected drive.
          Refer to smartd.conf(5) for the full directive reference.
        '';
      };
    };

    # ── Disk spindown ─────────────────────────────────────────────────────────

    spindown = {
      enable = lib.mkEnableOption "rotational-disk spindown via hdparm" // {
        default = true;
      };

      idleSeconds = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 1200; # 20 minutes
        example = 600;
        description = ''
          Idle time in seconds before a rotational drive spins down.
          Set to 0 to disable spindown even when enable = true.
          NVMe and SSD devices (queue/rotational == 0) are always skipped.
          The value is rounded to the nearest 5-second hdparm -S step.
        '';
      };
    };

    # ── Front-panel LED control ───────────────────────────────────────────────

    leds = {
      enable = lib.mkEnableOption "front-panel LED control via led-ugreen kernel module";

      # Packages — overridable so this module can be used outside this repo by
      # callers who supply their own builds.
      package = lib.mkOption {
        type = lib.types.package;
        # Default: build from the companion derivation in this repository.
        default = pkgs.callPackage ../../pkgs/ugreen-leds-utils { };
        defaultText = lib.literalExpression ''
          pkgs.callPackage <path-to-pkgs/ugreen-leds-utils> { }
        '';
        description = ''
          The ugreen-leds-utils package providing ugreen-diskiomon,
          ugreen-netdevmon, and ugreen-probe-leds.
        '';
      };

      kernelModulePackage = lib.mkOption {
        type = lib.types.package;
        # Default: build the led-ugreen.ko against the host's running kernel.
        default = config.boot.kernelPackages.callPackage ../../pkgs/ugreen-leds-kmod { };
        defaultText = lib.literalExpression ''
          config.boot.kernelPackages.callPackage <path-to-pkgs/ugreen-leds-kmod> { }
        '';
        description = ''
          The led-ugreen out-of-tree kernel module.  It registers the
          front-panel LEDs as Linux LED class devices under /sys/class/leds/
          so that ugreen-diskiomon and ugreen-netdevmon can bind triggers.
        '';
      };

      # ── Power LED ───────────────────────────────────────────────────────────
      #
      # Set once at boot by the ugreen-power-led oneshot service.  The MCU's
      # rolling boot animation also stops the first time any LED control
      # command is sent, so this serves as both the "exit animation" step AND
      # the steady-state power indicator.

      powerLed = {
        color = lib.mkOption {
          type = rgbType;
          default = "255 255 255"; # white
          example = "0 100 255";
          description = ''
            RGB colour of the power LED as three space-separated 0–255 values.
          '';
        };

        brightness = lib.mkOption {
          type = lib.types.ints.between 0 255;
          default = 128;
          description = "Brightness of the power LED (0 = off, 255 = maximum).";
        };
      };

      # ── Disk activity daemon ─────────────────────────────────────────────────

      diskiomon = {
        enable = lib.mkEnableOption "disk I/O activity and health monitoring daemon" // {
          default = false;
        };

        configFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression ''"/etc/ugreen-leds.conf"'';
          description = ''
            Path to the runtime configuration file for ugreen-diskiomon.
            When null the daemon uses /etc/ugreen-leds.conf if it exists,
            otherwise falls back to built-in defaults.
            See $out/share/ugreen-leds-utils/ugreen-leds.conf.example in
            the ugreen-leds-utils package for all available knobs.
          '';
        };
      };

      # ── Network activity daemon ───────────────────────────────────────────────

      netdevmon = {
        enable = lib.mkEnableOption "network link-state and activity monitoring daemon";

        interface = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "enp2s0";
          description = ''
            The network interface whose link state the netdev LED reflects.
            Must be set when netdevmon.enable = true.
          '';
        };

        configFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression ''"/etc/ugreen-leds.conf"'';
          description = ''
            Path to the runtime configuration file for ugreen-netdevmon.
            Same semantics as diskiomon.configFile.
          '';
        };
      };
    };
  };

  #############################################################################
  # Implementation
  #############################################################################

  config = lib.mkIf cfg.enable (
    lib.mkMerge [

      # ── Fan controller ──────────────────────────────────────────────────────

      (lib.mkIf cfg.it87.enable {
        # The mainline kernel ships an it87 driver but it does not recognise
        # the IT8613E chip ID.  The out-of-tree version in nixpkgs does, but
        # needs the chip ID forced via modprobe options.
        boot.extraModulePackages = [ config.boot.kernelPackages.it87 ];
        boot.kernelModules = [ "it87" ];
        boot.extraModprobeConfig = ''
          options it87 ignore_resource_conflict=1 force_id=${cfg.it87.forceId}
        '';

        environment.systemPackages = [ pkgs.lm_sensors ];
      })

      # ── SMART monitoring ─────────────────────────────────────────────────────

      (lib.mkIf cfg.smart.enable {
        services.smartd = {
          enable = true;
          autodetect = true;
          defaults.monitored = cfg.smart.monitoringDefaults;
        };

        environment.systemPackages = [ pkgs.smartmontools ];
      })

      # ── Disk spindown ─────────────────────────────────────────────────────────

      (lib.mkIf (cfg.spindown.enable && cfg.spindown.idleSeconds > 0) {
        services.udev.extraRules = ''
          # Spin down rotational drives after ${toString cfg.spindown.idleSeconds}s idle.
          # hdparm -S encodes intervals as (value * 5) seconds; we also set -B 127
          # which is the highest APM level that still allows spindown.
          ACTION=="add|change", KERNEL=="sd[a-z]", \
            ATTR{queue/rotational}=="1", \
            RUN+="${pkgs.hdparm}/bin/hdparm -S ${spindownHdparmValue} -B 127 /dev/%k"
        '';

        environment.systemPackages = [ pkgs.hdparm ];
      })

      # ── Front-panel LED kernel module ────────────────────────────────────────

      (lib.mkIf ledsCfg.enable {
        # led-ugreen.ko: provides /sys/class/leds/{power,netdev,disk1-8}
        # i2c-dev:       exposes /dev/i2c-N for direct I2C access (used by
        #                ugreen_leds_cli and by ugreen-probe-leds)
        # ledtrig_netdev: kernel LED trigger consumed by ugreen-netdevmon
        # ledtrig_oneshot: kernel LED trigger consumed by ugreen-diskiomon
        boot.extraModulePackages = [ ledsCfg.kernelModulePackage ];
        boot.kernelModules = [
          "led-ugreen"
          "i2c-dev"
          "ledtrig_netdev"
          "ledtrig_oneshot"
        ];

        environment.systemPackages = [
          pkgs.ugreen-leds-cli # for manual LED control / debugging
          ledsCfg.package # ugreen-diskiomon, ugreen-netdevmon, ugreen-probe-leds
        ];
      })

      # ── LED probe service (oneshot, required by all LED daemons) ─────────────

      (lib.mkIf ledsCfg.enable {
        # ugreen-probe-leds:
        #   1. Loads i2c-dev and led-ugreen kernel modules (belt-and-suspenders;
        #      boot.kernelModules handles this at boot, but the script checks too)
        #   2. Detects the SMBus I801 adapter via i2cdetect
        #   3. Registers the LED controller at I2C address 0x3a with led-ugreen
        # After this runs, /sys/class/leds/{power,netdev,disk1-4} are available.
        systemd.services.ugreen-probe-leds = {
          description = "Register UGREEN NASync LED controller on I2C bus";
          documentation = [ "https://github.com/miskcoo/ugreen_leds_controller" ];
          # Must run after the kernel module loading framework is up.
          after = [ "systemd-modules-load.service" ];
          wants = [ "systemd-modules-load.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${ledsCfg.package}/bin/ugreen-probe-leds";
            StandardOutput = "journal";
            StandardError = "journal";
          };
        };
      })

      # ── Power LED initial state (exits the MCU boot animation) ───────────────

      (lib.mkIf ledsCfg.enable {
        # The MCU's rolling boot animation stops the moment any LED control
        # command is sent over I2C.  This oneshot service sets the power LED to
        # a steady colour, which both silences the animation and establishes the
        # normal operational appearance.
        #
        # Note: uses ugreen_leds_cli (CLI tool via direct I2C) rather than the
        # sysfs interface because the sysfs "power" LED node is a single combined
        # device; the CLI is slightly more reliable for initial state-setting.
        systemd.services.ugreen-power-led = {
          description = "Set UGREEN NASync power LED initial state";
          after = [ "ugreen-probe-leds.service" ];
          requires = [ "ugreen-probe-leds.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # Use sysfs rather than ugreen_leds_cli.  After ugreen-probe-leds
            # registers led-ugreen on the I2C bus, the kernel marks that I2C
            # address as driver-owned and blocks raw /dev/i2c-N access from
            # userspace (which is what ugreen_leds_cli uses).  Writing to the
            # LED class device sysfs attributes goes through the driver instead
            # and works correctly.
            ExecStart = pkgs.writeShellScript "ugreen-power-led-init" ''
              echo "${ledsCfg.powerLed.color}" > /sys/class/leds/power/color
              echo "${toString ledsCfg.powerLed.brightness}" > /sys/class/leds/power/brightness
            '';
            StandardOutput = "journal";
            StandardError = "journal";
          };
        };
      })

      # ── Disk I/O monitoring daemon ───────────────────────────────────────────

      (lib.mkIf runDiskiomon {
        systemd.services.ugreen-diskiomon = {
          description = "UGREEN NASync disk-bay LED activity and health monitor";
          documentation = [ "https://github.com/miskcoo/ugreen_leds_controller" ];
          after = [
            "ugreen-probe-leds.service"
            "local-fs.target"
          ];
          requires = [ "ugreen-probe-leds.service" ];
          wantedBy = [ "multi-user.target" ];
          # Source the config file before the script runs so that MAPPING_METHOD
          # and disk serial assignments are respected.
          environment = lib.optionalAttrs (ledsCfg.diskiomon.configFile != null) {
            # The script sources /etc/ugreen-leds.conf; point it to the Nix path.
            UGREEN_LEDS_CONF = toString ledsCfg.diskiomon.configFile;
          };
          # Patch the script's config-file source path when a custom file is set.
          preStart = lib.mkIf (ledsCfg.diskiomon.configFile != null) ''
            # The script hard-codes /etc/ugreen-leds.conf; we symlink ours there
            # if nothing else owns it (non-destructive).
            if [[ ! -e /etc/ugreen-leds.conf ]]; then
              ln -sf ${toString ledsCfg.diskiomon.configFile} /etc/ugreen-leds.conf
            fi
          '';
          serviceConfig = {
            Type = "simple";
            ExecStart = "${ledsCfg.package}/bin/ugreen-diskiomon";
            Restart = "on-failure";
            RestartSec = "5s";
            StandardOutput = "journal";
            StandardError = "journal";
          };
        };
      })

      # ── Network LED monitoring daemon ────────────────────────────────────────

      (lib.mkIf runNetdevmon {
        assertions = [
          {
            assertion = ledsCfg.netdevmon.interface != null;
            message = ''
              hardware.ugreenNas.leds.netdevmon.enable is true but
              hardware.ugreenNas.leds.netdevmon.interface is not set.
              Set it to the interface whose link state should drive the LED,
              for example: hardware.ugreenNas.leds.netdevmon.interface = "enp2s0";
            '';
          }
        ];

        systemd.services.ugreen-netdevmon = {
          description = "UGREEN NASync network LED link-state monitor";
          documentation = [ "https://github.com/miskcoo/ugreen_leds_controller" ];
          after = [
            "ugreen-probe-leds.service"
            "network.target"
          ];
          requires = [ "ugreen-probe-leds.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            # Interface name is the sole positional argument.
            ExecStart = "${ledsCfg.package}/bin/ugreen-netdevmon ${
              lib.escapeShellArg (
                lib.optionalString (ledsCfg.netdevmon.interface != null) ledsCfg.netdevmon.interface
              )
            }";
            Restart = "on-failure";
            RestartSec = "5s";
            StandardOutput = "journal";
            StandardError = "journal";
          };
        };
      })

    ]
  );
}
