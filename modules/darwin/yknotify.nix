{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.yknotify;

  launcher = pkgs.writeShellApplication {
    name = "yknotify-launcher";
    runtimeInputs = [
      pkgs.yknotify
      pkgs.jq
      pkgs.terminal-notifier
    ];
    text = ''
      # Suppression window for USB-HID-LED-driven false positives. Our
      # notify-blink wrapper touches /tmp/notify-blink-active at the start of
      # every invocation; for ~suppressLedSeconds afterward we drop any
      # yknotify event because hidapi opens of the BlinkStick/blink(1) match
      # yknotify's same predicate the YubiKey does. See:
      # modules/home-manager/notification-leds.nix for the touch side, and
      # the project memory file usb-led-yknotify-collision.md for full context.
      LED_FLAG="/tmp/notify-blink-active"
      LED_SUPPRESS_SECONDS=${toString cfg.suppressLedSeconds}

      led_recently_active() {
        [ -f "$LED_FLAG" ] || return 1
        local now mtime
        now=$(/bin/date +%s)
        mtime=$(/usr/bin/stat -f %m "$LED_FLAG" 2>/dev/null || echo 0)
        (( now - mtime < LED_SUPPRESS_SECONDS ))
      }

      LAST_NTFY=0
      yknotify | while IFS= read -r line; do
        if led_recently_active; then
          continue
        fi
        NOW=$(date +%s)
        if (( NOW <= LAST_NTFY + ${toString cfg.dedupSeconds} )); then
          continue
        fi
        LAST_NTFY=$NOW
        message=$(jq -r '.type' <<< "$line")
        terminal-notifier \
          -title "yknotify" \
          -message "YubiKey touch: $message" \
          -sound "${cfg.sound}"
      done
    '';
  };
in
{
  options.services.yknotify = {
    enable = lib.mkEnableOption "yknotify YubiKey touch notifier (macOS)";

    sound = lib.mkOption {
      type = lib.types.str;
      default = "Submarine";
      description = "macOS system sound to play with the notification. See /System/Library/Sounds/.";
    };

    dedupSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Suppress duplicate notifications within this many seconds.";
    };

    suppressLedSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8;
      description = ''
        Suppress yknotify popups for this many seconds after notify-blink
        touches /tmp/notify-blink-active. Covers the full duration of an
        average blink (~4s for 30 repeats × 200ms × dual-device) with margin
        for the input-callback queue startup that hidapi triggers. Tune up
        if you still see false positives, down if real YubiKey touches get
        masked during long animations.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.yknotify ];

    launchd.user.agents.yknotify = {
      serviceConfig = {
        Label = "com.user.yknotify";
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/yknotify.out";
        StandardErrorPath = "/tmp/yknotify.err";
        ProgramArguments = [
          "${launcher}/bin/yknotify-launcher"
        ];
      };
    };
  };
}
