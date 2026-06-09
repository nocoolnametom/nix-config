{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.notification-leds;

  # BlinkStick Square driver implemented via hidapi instead of the
  # broken-on-macOS pyusb path that `python3Packages.blinkstick` uses.
  # Sets all 8 LEDs by looping Report 5 with a 10ms gap (the firmware
  # rejects rapid-fire reports without a brief settle time).
  blinkstickSquareDriver =
    pkgs.writers.writePython3Bin "blinkstick-square"
      {
        libraries = [ pkgs.python3Packages.hid ];
        # Disable flake8 style checks — this is a tiny single-purpose script and
        # the default writers lint complains about line length, alignment, and
        # whitespace patterns we use for readable column-aligned tables.
        flakeIgnore = [
          "E501" # line too long
          "E126" # continuation line over-indented for hanging indent
          "E127" # continuation line over-indented for visual indent
          "E128" # continuation line under-indented for visual indent
          "E201" # whitespace after '('
          "E202" # whitespace before ')'
          "E221" # multiple spaces before operator
          "E222" # multiple spaces after operator
          "E241" # multiple spaces after ','
          "E302" # expected 2 blank lines (between defs)
          "E305" # expected 2 blank lines after class or function
          "W391" # blank line at end of file
          "W292" # no newline at end of file
        ];
      }
      ''
        """BlinkStick Square driver via hidapi.

        Usage:
          blinkstick-square set-color <color>
          blinkstick-square blink <color> [--repeats N] [--delay MS]
          blinkstick-square off

        Bypasses python3Packages.blinkstick's pyusb backend which fails on
        macOS due to IOKit's claim on USB HID devices. Uses hidapi (IOHidManager
        on macOS, libusb/hidraw on Linux) via the `hid` Python binding.
        """
        import argparse
        import hid
        import sys
        import time

        VID, PID = 0x20a0, 0x41e5
        NUM_LEDS = 8
        INTER_LED_DELAY_MS = 10  # firmware needs ~10ms between Report 5 sends

        NAMED_COLORS = {
            "red":     (255,   0,   0),
            "green":   (0,   255,   0),
            "blue":    (0,     0, 255),
            "yellow":  (255, 255,   0),
            "cyan":    (0,   255, 255),
            "magenta": (255,   0, 255),
            "white":   (255, 255, 255),
            "orange":  (255, 100,   0),
            "purple":  (128,   0, 128),
            "off":     (0,     0,   0),
            "black":   (0,     0,   0),
        }

        def parse_color(s):
            s = s.strip().lower()
            if s in NAMED_COLORS:
                return NAMED_COLORS[s]
            h = s.lstrip("#")
            if len(h) == 6 and all(c in "0123456789abcdef" for c in h):
                return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
            raise ValueError(f"Unknown color: {s!r}")

        def set_all(dev, r, g, b):
            for i in range(NUM_LEDS):
                dev.send_feature_report(bytes([5, 0, i, r, g, b]))
                if INTER_LED_DELAY_MS:
                    time.sleep(INTER_LED_DELAY_MS / 1000)

        def main():
            p = argparse.ArgumentParser(description="BlinkStick Square driver (hidapi)")
            sub = p.add_subparsers(dest="cmd", required=True)
            sc = sub.add_parser("set-color")
            sc.add_argument("color")
            bk = sub.add_parser("blink")
            bk.add_argument("color")
            bk.add_argument("--repeats", type=int, default=3)
            bk.add_argument("--delay", type=int, default=200,
                            help="milliseconds per on/off phase")
            sub.add_parser("off")
            args = p.parse_args()

            try:
                dev = hid.Device(VID, PID)
            except Exception as e:
                print(f"blinkstick-square: device not found ({e})", file=sys.stderr)
                sys.exit(1)

            try:
                if args.cmd == "set-color":
                    r, g, b = parse_color(args.color)
                    set_all(dev, r, g, b)
                elif args.cmd == "off":
                    set_all(dev, 0, 0, 0)
                elif args.cmd == "blink":
                    r, g, b = parse_color(args.color)
                    for _ in range(args.repeats):
                        set_all(dev, r, g, b)
                        time.sleep(args.delay / 1000)
                        set_all(dev, 0, 0, 0)
                        time.sleep(args.delay / 1000)
            finally:
                dev.close()

        if __name__ == "__main__":
            main()
      '';

  # Build a bash case branch per declared source. Each branch sets the
  # COLOR/REPEATS/DELAY/DEVICES bash variables from the source's config.
  sourceBranches = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: src: ''
      ${name})
        COLOR=${lib.escapeShellArg src.color}
        REPEATS="${toString src.repeats}"
        DELAY="${toString src.delay}"
        DEVICES=(${lib.concatStringsSep " " (map lib.escapeShellArg src.devices)})
        ;;'') cfg.sources
  );

  # blink1-tool source:
  #   - Linux: pkgs.blink1-tool (nixpkgs); meta.platforms restricts it to linux.
  #   - Darwin: not in nixpkgs at all; installed via `homebrew.brews` (the
  #     `blink1` formula provides homebrew blink1-tool).
  # Including the package in runtimeInputs on Linux puts it on the wrapper's
  # PATH; on darwin we probe homebrew bin directory and /usr/local/bin.
  blink1Pkgs = lib.optional pkgs.stdenv.isLinux pkgs.blink1-tool;

  notifyBlinkScript = pkgs.writeShellApplication {
    name = "notify-blink";
    runtimeInputs = [ blinkstickSquareDriver ] ++ blink1Pkgs;
    text = ''
      # notify-blink — drive USB notification LEDs.
      #
      # Usage:
      #   notify-blink <source>               # use configured source
      #   notify-blink <color> [reps] [delay] # ad-hoc color+timing
      #   notify-blink off                    # turn all configured LEDs off
      #
      # Add --device <square|blink1|both> to override the target device(s).
      # Defaults to all devices configured for the source (or both for
      # ad-hoc invocations).
      #
      # Continuous-until-acknowledged pattern: caller polls the underlying
      # state and re-issues `notify-blink <source>` every few seconds while
      # the condition holds. With default repeats=10 + delay=200ms, each
      # call gives ~4s of blinking, so a 2-3s polling cadence keeps the
      # LED continuously alive. Issue `notify-blink off` once on the
      # transition back to "no notification".

      # Defaults (overridden by source config or positional args)
      COLOR=""
      REPEATS=10
      DELAY=200
      DEVICES=("square" "blink1")
      DEVICE_OVERRIDE=""

      # Pull --device out of positional args
      POSITIONAL=()
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --device)
            DEVICE_OVERRIDE="''${2:-}"
            shift 2
            ;;
          -h|--help)
            grep -E "^[[:space:]]*#" "$0" | sed -E 's/^[[:space:]]*# ?//' | head -25
            exit 0
            ;;
          *)
            POSITIONAL+=("$1")
            shift
            ;;
        esac
      done
      set -- "''${POSITIONAL[@]}"

      INPUT="''${1:-}"
      if [ -z "$INPUT" ]; then
        echo "Usage: notify-blink <source|color|off> [reps] [delay] [--device square|blink1|both]" >&2
        exit 1
      fi

      # USB-HID open/startQueue events from our LED devices match yknotify's
      # tracking + trigger regexes verbatim — yknotify can't tell our hidapi
      # opens apart from a YubiKey FIDO2 client. Touch a marker so the
      # yknotify-launcher can suppress its notification during/just after a
      # notify-blink call. (See modules/darwin/yknotify.nix for the read side.)
      /usr/bin/touch /tmp/notify-blink-active 2>/dev/null || true

      case "$INPUT" in
        ${sourceBranches}
        off)
          COLOR=off
          ;;
        *)
          COLOR="$INPUT"
          REPEATS="''${2:-3}"
          DELAY="''${3:-200}"
          ;;
      esac

      # Normalize COLOR to a 6-digit hex string. blink1-tool only accepts hex
      # or RGB triples (not names), and the BlinkStick driver accepts both
      # names and hex — passing hex to both keeps behavior uniform.
      to_hex() {
        local c
        c="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
        case "$c" in
          red)             echo "FF0000" ;;
          green)           echo "00FF00" ;;
          blue)            echo "0000FF" ;;
          yellow)          echo "FFFF00" ;;
          cyan)            echo "00FFFF" ;;
          magenta)         echo "FF00FF" ;;
          white)           echo "FFFFFF" ;;
          orange)          echo "FF6400" ;;
          purple)          echo "800080" ;;
          off|black)       echo "000000" ;;
          \#*)             echo "''${c#\#}" | tr '[:lower:]' '[:upper:]' ;;
          *)               echo "$c" | tr '[:lower:]' '[:upper:]' ;;
        esac
      }
      COLOR_HEX="$(to_hex "$COLOR")"

      case "$DEVICE_OVERRIDE" in
        "")     ;;
        both)    DEVICES=("square" "blink1") ;;
        square)  DEVICES=("square") ;;
        blink1)  DEVICES=("blink1") ;;
        *) echo "Unknown --device: $DEVICE_OVERRIDE (expected square|blink1|both)" >&2; exit 1 ;;
      esac

      BLINK1_BIN=""
      if command -v blink1-tool >/dev/null 2>&1; then
        BLINK1_BIN="$(command -v blink1-tool)"
      fi

      drive_square() {
        if [ "$COLOR_HEX" = "000000" ]; then
          blinkstick-square off 2>/dev/null &
        else
          blinkstick-square blink "$COLOR_HEX" --repeats "$REPEATS" --delay "$DELAY" 2>/dev/null &
        fi
        return 0
      }

      drive_blink1() {
        [ -z "$BLINK1_BIN" ] && return 1
        if [ "$COLOR_HEX" = "000000" ]; then
          "$BLINK1_BIN" --off >/dev/null 2>&1 &
        else
          # blink1-tool wants bare hex (no "0x" prefix — that parses as white).
          "$BLINK1_BIN" --rgb "$COLOR_HEX" --blink "$REPEATS" --delay "$DELAY" >/dev/null 2>&1 &
        fi
        return 0
      }

      DEVICE_PIDS=()
      for dev in "''${DEVICES[@]}"; do
        case "$dev" in
          square) drive_square && DEVICE_PIDS+=("$!") ;;
          blink1) drive_blink1 && DEVICE_PIDS+=("$!") ;;
        esac
      done

      # Keep /tmp/notify-blink-active fresh for the full duration of the blink
      # animation. The Python BlinkStick driver and blink1-tool both run as
      # backgrounded children above; a single up-front touch isn't enough
      # because yknotify keeps emitting startQueue events through every blink
      # iteration. The refresher dies via trap when the wrapper exits.
      (
        while sleep 2; do
          /usr/bin/touch /tmp/notify-blink-active 2>/dev/null || true
        done
      ) &
      REFRESH_PID=$!
      trap 'kill $REFRESH_PID 2>/dev/null; /usr/bin/touch /tmp/notify-blink-active 2>/dev/null || true' EXIT

      # Wait only on device PIDs — `wait` (no args) would hang on the
      # refresher's infinite loop.
      if [ ''${#DEVICE_PIDS[@]} -gt 0 ]; then
        wait "''${DEVICE_PIDS[@]}" 2>/dev/null || true
      fi
    '';
  };
in
{
  options.services.notification-leds = {
    enable = lib.mkEnableOption "USB LED notification devices (BlinkStick Square + ThingM blink(1))";

    sources = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            color = lib.mkOption {
              type = lib.types.str;
              description = ''
                Color for this source. Named color ("red", "green",
                "blue", "yellow", etc.) or 6-digit hex (e.g. "FF8800",
                with or without leading "#"). Both the BlinkStick and
                blink(1) drivers accept the same vocabulary.
              '';
              example = "red";
            };
            devices = lib.mkOption {
              type = lib.types.listOf (
                lib.types.enum [
                  "square"
                  "blink1"
                ]
              );
              default = [
                "square"
                "blink1"
              ];
              description = ''
                Which device(s) fire when this source triggers.
                "square" = the BlinkStick Square; "blink1" = the
                ThingM blink(1). Use both for max visibility.
              '';
            };
            repeats = lib.mkOption {
              type = lib.types.int;
              default = 10;
              description = ''
                Number of blink repetitions per `notify-blink` call.
                Higher values give longer continuous blinking — useful
                when paired with a polling source that re-issues the
                blink every few seconds while the underlying condition
                still holds (continuous-until-acknowledged pattern).
              '';
            };
            delay = lib.mkOption {
              type = lib.types.int;
              default = 200;
              description = "Per-blink-phase duration in milliseconds.";
            };
          };
        }
      );
      default = { };
      description = ''
        Notification source → visual mapping. Each source has a color
        and a target device list; call `notify-blink <source>` to fire
        it. Configure once here, then any integration (sketchybar
        widget, launchd timer, etc.) just calls `notify-blink <source>`
        without needing to know the visual specifics.
      '';
      example = lib.literalExpression ''
        {
          slack    = { color = "red";    devices = [ "square" "blink1" ]; repeats = 30; };
          email    = { color = "blue";   devices = [ "square" ]; };
          calendar = { color = "yellow"; devices = [ "blink1" ]; };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      blinkstickSquareDriver
      notifyBlinkScript
    ]
    ++ blink1Pkgs;
  };
}
