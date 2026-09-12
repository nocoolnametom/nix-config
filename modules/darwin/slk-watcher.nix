{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.services.slk-watcher;

  # Escape a literal string for safe use as an ERE pattern (grep -E).
  # All regex metacharacters are backslash-prefixed so the string is matched
  # verbatim. Order doesn't matter because lib.replaceStrings does a single
  # left-to-right pass that never re-processes replaced content.
  escapeRegex =
    s:
    lib.replaceStrings
      [
        "\\"
        "."
        "*"
        "+"
        "?"
        "["
        "]"
        "{"
        "}"
        "("
        ")"
        "^"
        "$"
        "|"
      ]
      [
        "\\\\"
        "\\."
        "\\*"
        "\\+"
        "\\?"
        "\\["
        "\\]"
        "\\{"
        "\\}"
        "\\("
        "\\)"
        "\\^"
        "\\$"
        "\\|"
      ]
      s;

  # When defaultSource is set, fire it for every new message regardless of patterns.
  # Use this to cover the "all messages" case when slk is acting as the sole
  # LED driver (paired with notification-watcher's inhibitWhenTmuxSession).
  defaultSourceFire = lib.optionalString (cfg.defaultSource != "") ''
    maybe_fire '__default__' ${lib.escapeShellArg cfg.defaultSource}
  '';

  # Build one "if grep … maybe_fire" block per configured source.
  # Sources with no patterns at all are omitted to avoid matching everything.
  sourceChecks = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      sourceName: src:
      let
        # handles → <@ID> patterns (how Slack encodes @-mentions in message text)
        handlePatterns = map (h: "<@${h}>") src.handles;
        # keywords → regex-escaped literal strings
        keywordPatterns = map escapeRegex src.keywords;
        allPatterns = src.patterns ++ handlePatterns ++ keywordPatterns;
        combinedPattern = lib.concatStringsSep "|" allPatterns;
      in
      lib.optionalString (allPatterns != [ ]) ''
        # Source: ${sourceName} → notify-blink ${src.notifySource}
        if printf '%s' "$msg_text" | grep -qEi ${lib.escapeShellArg combinedPattern}; then
          maybe_fire ${lib.escapeShellArg sourceName} ${lib.escapeShellArg src.notifySource}
        fi
      ''
    ) cfg.sources
  );

  bgCfg = cfg.background;

  # Keeps slk alive in a detached tmux session so the SQLite cache stays fresh
  # even when no interactive terminal has slk open. launchd calls this script
  # on a timer; it is a no-op if the session is already running.
  #
  # ── Attaching to the live TUI ────────────────────────────────────────────
  #   tmux attach -t slk-bg        # bring the session to your current terminal
  #   <use slk normally>
  #   Ctrl-b d                      # detach — slk keeps running in background
  #
  # ── Other useful commands ─────────────────────────────────────────────────
  #   tmux ls                       # list all sessions (confirm slk-bg is there)
  #   tmux has-session -t slk-bg && echo running || echo stopped
  #   tmux kill-session -t slk-bg   # stop the background slk entirely
  # ─────────────────────────────────────────────────────────────────────────
  bgLauncherScript = pkgs.writeShellApplication {
    name = "slk-bg-launcher";
    runtimeInputs = [ pkgs.tmux ];
    text = ''
      # slk-bg-launcher — ensure slk is running in a detached tmux session.
      #
      # Called periodically by launchd (StartInterval). If the session exists
      # and slk is alive inside it, this exits immediately as a no-op. If slk
      # crashed or was killed, the next timer tick recreates the session.
      #
      # ── Interaction guide (copy-paste ready) ────────────────────────────
      #
      #   Attach to the live TUI:
      #     tmux attach -t ${bgCfg.sessionName}
      #
      #   Detach and leave slk running in the background:
      #     Ctrl-b  then  d
      #       (Ctrl-b is the default tmux prefix; change it if you rebind it)
      #
      #   Check whether the background session is alive:
      #     tmux has-session -t ${bgCfg.sessionName} && echo running || echo stopped
      #
      #   Stop the background slk entirely (launchd will restart it on the next tick):
      #     tmux kill-session -t ${bgCfg.sessionName}
      #
      #   Stop it permanently (until the next darwin-rebuild switch):
      #     launchctl unload ~/Library/LaunchAgents/org.nixos.slk-bg-launcher.plist
      # ────────────────────────────────────────────────────────────────────
      #
      # slk is a Homebrew cask so /opt/homebrew/bin is added explicitly —
      # launchd agents do not source the user shell profile where brew shellenv runs.

      export PATH="$HOME/.nix-profile/bin:/run/current-system/sw/bin:/opt/homebrew/bin:$PATH"

      SESSION=${lib.escapeShellArg bgCfg.sessionName}

      if tmux has-session -t "$SESSION" 2>/dev/null; then
        # Session exists — slk is still running; nothing to do.
        exit 0
      fi

      if ! command -v slk >/dev/null 2>&1; then
        echo "[$(date)] slk-bg-launcher: slk not found on PATH; is gammons/tap/slk installed via Homebrew?" >&2
        exit 1
      fi

      echo "[$(date)] slk-bg-launcher: (re)creating tmux session '$SESSION'"
      tmux new-session -d -s "$SESSION" slk
    '';
  };

  watcherScript = pkgs.writeShellApplication {
    name = "slk-watcher";
    # sqlite3 from nixpkgs ensures -json output mode (added in SQLite 3.33, 2020).
    # jq handles newlines inside message text — json_each-style per-row output
    # keeps message parsing unambiguous even when Slack messages span multiple lines.
    runtimeInputs = [
      pkgs.sqlite
      pkgs.jq
    ];
    text = ''
      # slk-watcher — poll slk's SQLite message cache for new Slack messages
      # matching configured handles/keywords/patterns, and fire notify-blink
      # for each matched source.
      #
      # Called on a timer by launchd (StartInterval); each invocation is short-lived.
      # Requires slk (gammons/tap/slk) to be open so its cache stays current.
      # When slk is not running, the cache goes stale and no new messages are seen;
      # the existing notification-watcher (macOS bundle-ID based) remains active
      # as a fallback for generic Slack notifications.
      #
      # State files:
      #   ~/.local/state/slk-watcher/watermark   last processed created_at epoch
      #   ~/.local/state/slk-watcher/cooldowns/  per-source last-fired timestamps

      export PATH="$HOME/.nix-profile/bin:/run/current-system/sw/bin:$PATH"

      # Resolve the database path (may be overridden via the Nix option).
      if [ -n ${lib.escapeShellArg cfg.dbPath} ]; then
        DB_PATH=${lib.escapeShellArg cfg.dbPath}
      else
        DB_PATH="$HOME/.local/share/slk/cache.db"
      fi

      STATE_DIR="$HOME/.local/state/slk-watcher"
      WATERMARK_FILE="$STATE_DIR/watermark"
      COOLDOWN_DIR="$STATE_DIR/cooldowns"

      mkdir -p "$STATE_DIR" "$COOLDOWN_DIR"

      # On first run, initialize the watermark to now so historical messages
      # don't trigger LED blasts on startup.
      if [ ! -f "$WATERMARK_FILE" ]; then
        date +%s > "$WATERMARK_FILE"
        echo "slk-watcher: initialized watermark to $(cat "$WATERMARK_FILE"), starting fresh"
        exit 0
      fi

      # If slk hasn't created the database yet, there's nothing to do.
      if [ ! -f "$DB_PATH" ]; then
        exit 0
      fi

      LAST_TS=$(cat "$WATERMARK_FILE")
      LATEST_TS="$LAST_TS"
      FOUND_ANY=0

      # Fire notify-blink for a watcher source, honouring per-source cooldown.
      # Cooldown prevents LED spam when many matching messages arrive in a burst.
      # Args: $1 = watcher source name (for cooldown key)
      #       $2 = notify-blink source name (for LED config lookup)
      maybe_fire() {
        local watcher_source="$1"
        local notify_source="$2"
        local cooldown_file="$COOLDOWN_DIR/$watcher_source"
        local now
        now=$(date +%s)

        if [ -f "$cooldown_file" ]; then
          local last_fired elapsed
          last_fired=$(cat "$cooldown_file")
          elapsed=$(( now - last_fired ))
          if [ "$elapsed" -lt ${toString cfg.cooldown} ]; then
            echo "[$(date +%T)] slk-watcher: $watcher_source in cooldown ($elapsed/${toString cfg.cooldown}s elapsed), skipping"
            return 0
          fi
        fi

        echo "$now" > "$cooldown_file"
        echo "[$(date +%T)] slk-watcher: matched $watcher_source → notify-blink $notify_source"
        if command -v notify-blink >/dev/null 2>&1; then
          notify-blink "$notify_source" >/dev/null 2>&1 &
        fi
      }

      # Query new messages since the last watermark.
      # - created_at: integer unix epoch inserted by slk when it cached the row
      # - text: the Slack message body (may contain newlines — jq handles that)
      # - sqlite3 -json outputs a JSON array; jq -c '.[]' emits one compact
      #   object per line, safely encoding any embedded newlines or special chars.
      while IFS= read -r entry; do
        created_at=$(printf '%s' "$entry" | jq -r '.created_at // empty')
        msg_text=$(printf '%s' "$entry" | jq -r '.text // empty')

        [ -z "$created_at" ] || [ -z "$msg_text" ] && continue

        FOUND_ANY=1
        if [ "$created_at" -gt "$LATEST_TS" ]; then
          LATEST_TS="$created_at"
        fi

        ${defaultSourceFire}
        ${sourceChecks}
      done < <(
        sqlite3 -json "$DB_PATH" \
          "SELECT created_at, text FROM messages
           WHERE created_at > ${"\${LAST_TS}"} AND created_at > 0 AND is_deleted = 0
           ORDER BY created_at ASC;" \
          2>/dev/null \
          | jq -c '.[]' 2>/dev/null
      )

      if [ "$FOUND_ANY" -eq 1 ]; then
        echo "$LATEST_TS" > "$WATERMARK_FILE"
      fi
    '';
  };
in
{
  options.services.slk-watcher = {
    enable = lib.mkEnableOption "slk SQLite cache watcher (fires notify-blink on pattern-matched Slack messages)";

    dbPath = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Absolute path to slk's SQLite message cache.
        Defaults to $HOME/.local/share/slk/cache.db (resolved at runtime).
        Set this only if slk's XDG_DATA_HOME is non-standard.
      '';
    };

    pollInterval = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = ''
        Seconds between database polls (launchd StartInterval).
        Lower values = more responsive LEDs; higher values = less disk churn.
      '';
    };

    cooldown = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = ''
        Minimum seconds between firings for the same watcher source.
        Prevents LED spam when many matching messages arrive in a burst.
      '';
    };

    defaultSource = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        If non-empty, fire `notify-blink <defaultSource>` for every new
        message in the slk cache, regardless of pattern matches.

        Pair this with `services.notification-watcher.sources.<name>.inhibitWhenTmuxSession`
        set to the same tmux session name as `background.sessionName` to make
        slk-watcher the sole LED driver while slk is running, with
        notification-watcher automatically taking over when slk stops:

          # in slk-watcher config:
          defaultSource = "slack";   # fires red for all messages
          background.sessionName = "slk-bg";

          # in notification-watcher config:
          sources.slack.inhibitWhenTmuxSession = "slk-bg";
      '';
      example = "slack";
    };

    sources = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            handles = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                Slack user IDs (e.g. "U0A123ABC") whose @-mentions trigger this
                source. Slack encodes mentions as <@USERID> in message text, so
                each entry here matches that literal pattern.

                Find your user ID:
                  sqlite3 ~/.local/share/slk/cache.db \
                    "SELECT id, name, display_name FROM users WHERE name LIKE '%yourname%';"
              '';
              example = [ "U0A123ABC" ];
            };

            keywords = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                Literal strings (case-insensitive) whose presence in message
                text triggers this source. No regex knowledge needed — special
                characters are automatically escaped.
              '';
              example = [
                "urgent"
                "P0"
                "on fire"
              ];
            };

            patterns = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                Extended regexes (grep -E -i) matched against message text.
                Use for anything handles/keywords can't express — e.g. whole-word
                matching, alternation, or Slack broadcast tokens like @here.
              '';
              example = [
                "\\bpaging\\b"
                "@here"
                "@channel"
              ];
            };

            notifySource = lib.mkOption {
              type = lib.types.str;
              description = ''
                The `notify-blink` source name to fire on a match. Must exist
                in `services.notification-leds.sources` (configured in the
                notification-leds home-manager module) for the LED to actually fire.
              '';
              example = "slack-mention";
            };
          };
        }
      );
      default = { };
      description = ''
        Named pattern groups. Each entry watches for its handles/keywords/patterns
        in new Slack message text and fires `notify-blink <notifySource>` on a match.

        Patterns within a single source are OR'd (any match fires).
        Sources are evaluated independently, so one message can trigger multiple sources.

        Example — fire orange on any @-mention or @here/@channel, and fire magenta
        on urgent keywords:

          sources = {
            mention = {
              handles  = [ "U0A123ABC" ];   # your Slack user ID
              patterns = [ "@here" "@channel" ];
              notifySource = "slack-mention";
            };
            urgent = {
              keywords = [ "urgent" "P0" "outage" ];
              notifySource = "slack-urgent";
            };
          };
      '';
    };

    background = {
      enable = lib.mkEnableOption "keep slk alive in a detached tmux session for continuous cache updates";

      sessionName = lib.mkOption {
        type = lib.types.str;
        default = "slk-bg";
        description = ''
          Name of the tmux session that hosts the background slk instance.

          Attach any time:       tmux attach -t <sessionName>
          Detach (slk stays up): Ctrl-b then d
          Kill the session:      tmux kill-session -t <sessionName>
        '';
      };

      checkInterval = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = ''
          Seconds between liveness checks (launchd StartInterval).
          If slk crashes, the next tick recreates the tmux session automatically.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        launchd.user.agents.slk-watcher = {
          command = "${watcherScript}/bin/slk-watcher";
          serviceConfig = {
            # One-shot per invocation — launchd handles the re-run cadence.
            KeepAlive = false;
            RunAtLoad = true;
            StartInterval = cfg.pollInterval;
            StandardOutPath = "/tmp/slk-watcher.log";
            StandardErrorPath = "/tmp/slk-watcher.log";
          };
        };
      }
      (lib.mkIf bgCfg.enable {
        launchd.user.agents.slk-bg-launcher = {
          command = "${bgLauncherScript}/bin/slk-bg-launcher";
          serviceConfig = {
            # One-shot: the sh exits immediately after tmux forks slk into its
            # own server process. launchd's StartInterval handles the periodic
            # re-check. KeepAlive would just restart the wrapper endlessly
            # rather than monitoring the tmux session.
            KeepAlive = false;
            RunAtLoad = true;
            StartInterval = bgCfg.checkInterval;
            StandardOutPath = "/tmp/slk-bg-launcher.log";
            StandardErrorPath = "/tmp/slk-bg-launcher.log";
          };
        };
      })
    ]
  );
}
