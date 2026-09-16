{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.yknotify;

  # Group ID used with terminal-notifier so yknotify-dismiss can remove banners.
  notifierGroup = "yknotify";

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

      # yknotify's IOKit predicate matches any HID device open — not just
      # YubiKeys. LED devices (BlinkStick, Luxafor, blink(1), Kuando) all
      # generate the same events. This check queries the USB device tree for
      # Yubico's vendor ID (0x1050 = 4176 decimal) so we only notify when a
      # YubiKey is physically connected. LED devices have different VIDs and
      # will never match, eliminating that entire class of false positives
      # without relying on timing-sensitive suppress windows.
      yubico_connected() {
        /usr/sbin/ioreg -p IOUSB -l 2>/dev/null | /usr/bin/grep -q '"idVendor" = 4176'
      }

      LAST_NTFY=0
      yknotify | while IFS= read -r line; do
        if ! yubico_connected; then
          continue
        fi
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
          -group "${notifierGroup}" \
          -sound "${cfg.sound}"
      done
    '';
  };

  # Helper script: dismisses any live yknotify banner and restarts the launchd
  # agent so a stuck/spurious yknotify process is killed cleanly without
  # needing an actual YubiKey touch.
  dismiss = pkgs.writeShellApplication {
    name = "yknotify-dismiss";
    runtimeInputs = [ pkgs.terminal-notifier ];
    text = ''
      terminal-notifier -remove "${notifierGroup}"
      launchctl stop com.user.yknotify
      launchctl start com.user.yknotify
      # Also turn off any stuck notification LEDs that may have triggered the
      # false yknotify alert. notify-blink is a home-manager package; probe
      # the user profile for it and skip silently if it isn't there.
      NOTIFY_BLINK="$HOME/.nix-profile/bin/notify-blink"
      if [ -x "$NOTIFY_BLINK" ]; then
        "$NOTIFY_BLINK" off >/dev/null 2>&1 || true
      fi
      echo "yknotify restarted"
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
    environment.systemPackages = [
      pkgs.yknotify
      dismiss
    ];

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
