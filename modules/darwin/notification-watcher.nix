{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.notification-watcher;

  # Build the bash case branches that map bundle ID → notify-blink source name.
  bundleCases = lib.concatStringsSep "\n        " (
    lib.concatLists (
      lib.mapAttrsToList (
        sourceName: src:
        map (
          bundleId: "${lib.escapeShellArg bundleId}) source_name=${lib.escapeShellArg sourceName} ;;"
        ) src.bundleIds
      ) cfg.sources
    )
  );

  watcherScript = pkgs.writeShellApplication {
    name = "notification-watcher";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      # macOS notification watcher — dbus-equivalent for user notifications.
      #
      # Subscribes to /usr/bin/log stream (the macOS Unified Logging system)
      # filtered to notification-delivery events emitted by usernotificationsd.
      # No special permissions required — `log` is user-accessible.
      #
      # For each new notification, looks up the source's bundle ID against
      # configured mappings and invokes `notify-blink <source-name>` to drive
      # the configured LED(s). De-duplicates by notification ID so multiple
      # log lines for the same notification only fire one blink.
      #
      # Source-to-bundle-ID mapping comes from
      # `services.notification-watcher.sources` (configured per-host).

      # User's home-manager profile path so `notify-blink` is reachable
      # even though launchd agents start with a minimal env.
      export PATH="$HOME/.nix-profile/bin:/run/current-system/sw/bin:$PATH"

      # Bounded dedupe cache. Each notification generates several log lines
      # (Request: Starting, Step 0, Step 1, ...). We only want to fire once
      # per notification id. The cache rotates so it doesn't grow unbounded.
      declare -a SEEN_IDS=()
      declare -A SEEN_MAP=()
      SEEN_MAX=200

      remember_id() {
        local id="$1"
        SEEN_MAP["$id"]=1
        SEEN_IDS+=("$id")
        if [ "''${#SEEN_IDS[@]}" -gt "$SEEN_MAX" ]; then
          local drop="''${SEEN_IDS[0]}"
          SEEN_IDS=("''${SEEN_IDS[@]:1}")
          unset "SEEN_MAP[$drop]"
        fi
      }

      echo "notification-watcher started at $(date)"

      /usr/bin/log stream \
        --level debug \
        --style ndjson \
        --predicate 'subsystem == "com.apple.usernotificationsd" AND category == "NotificationsPipeline" AND eventMessage CONTAINS "Request: Starting"' \
        | while IFS= read -r line; do
        # Skip the header line(s) /usr/bin/log emits when starting
        case "$line" in
          '{'*) : ;;  # ndjson event line, process below
          *) continue ;;
        esac

        msg=$(printf '%s' "$line" | jq -r '.eventMessage // empty' 2>/dev/null)
        [ -z "$msg" ] && continue

        # Only fire on actual "create" events (new notification arrived).
        # Skip updates, removes, etc.
        case "$msg" in
          *"[create,"*) : ;;
          *) continue ;;
        esac

        # Parse `bundle=<id>` and `id=<value>` out of the event message.
        bundle=$(printf '%s' "$msg" | grep -oE 'bundle=[a-zA-Z0-9._-]+' | head -1 | cut -d= -f2)
        notif_id=$(printf '%s' "$msg" | grep -oE 'id=[A-Za-z0-9-]+' | head -1 | cut -d= -f2)

        [ -z "$bundle" ] && continue
        [ -z "$notif_id" ] && continue

        # Dedupe — only fire once per notification id.
        if [ -n "''${SEEN_MAP[$notif_id]:-}" ]; then
          continue
        fi
        remember_id "$notif_id"

        # Map bundle id → source name.
        source_name=""
        case "$bundle" in
          ${bundleCases}
          *) continue ;;
        esac
        [ -z "$source_name" ] && continue

        # Fire. Backgrounded so a slow blink doesn't block log streaming.
        if command -v notify-blink >/dev/null 2>&1; then
          notify-blink "$source_name" >/dev/null 2>&1 &
        fi
        echo "[$(date +%T)] $bundle (id=$notif_id) → $source_name"
      done
    '';
  };
in
{
  options.services.notification-watcher = {
    enable = lib.mkEnableOption "macOS notification delivery watcher (drives notify-blink LEDs)";

    sources = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            bundleIds = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = ''
                Bundle IDs whose notification deliveries fire this source.
                Find a bundle ID with:
                  osascript -e 'id of application "App Name"'
                or for already-running apps:
                  ps -A -o command | grep <appname>
              '';
              example = [
                "com.apple.mail"
                "com.fastmail.mail"
              ];
            };
          };
        }
      );
      default = { };
      description = ''
        Maps `notify-blink` source names → lists of macOS bundle IDs.
        When a notification from any matching app is delivered, the watcher
        fires `notify-blink <source-name>` which drives the configured LEDs
        (see the notification-leds home-manager module).

        The keys here MUST match keys in
        `services.notification-leds.sources` for the LED to actually fire.
      '';
      example = lib.literalExpression ''
        {
          slack    = { bundleIds = [ "com.tinyspeck.slackmacgap" ]; };
          email    = { bundleIds = [ "com.apple.mail" ]; };
          calendar = { bundleIds = [ "com.apple.iCal" "com.TickTick.task.mac" ]; };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.user.agents.notification-watcher = {
      command = "${watcherScript}/bin/notification-watcher";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/notification-watcher.log";
        StandardErrorPath = "/tmp/notification-watcher.log";
      };
    };
  };
}
