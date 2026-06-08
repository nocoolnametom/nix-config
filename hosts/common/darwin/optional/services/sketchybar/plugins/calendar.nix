{
  pkgs,
  lib ? pkgs.lib,
  writeShellScript ? pkgs.writeShellScript,
  # List of calendar identifiers to include (display names OR UUIDs from
  # `icalBuddy calendars`). UUIDs are preferred for repo-safety — they reveal
  # no PII. Empty list (default) → all calendars are queried.
  includedCalendars ? [ ],
  # User-provided skip patterns (case-insensitive literal substrings).
  # Combined with the defaults below.
  skipPatterns ? [ ],
  ...
}:
let
  # Always-applied defaults. Catch the common noise:
  #   "(Canceled)" / "(Cancelled)" — cancelled-but-not-deleted invitations
  #   "OOO" / "Out of Office"      — Workday-generated time-off events
  #   "Birthday"                   — if a Birthdays calendar is in the include list
  #   "Holiday"                    — if a Holidays calendar is in the include list
  defaultSkipPatterns = [
    "(Canceled)"
    "(Cancelled)"
    "OOO"
    "Out of Office"
    "Birthday"
    "Holiday"
  ];
  allSkipPatterns = defaultSkipPatterns ++ skipPatterns;
  # Render the patterns as a bash array literal: "pat1" "pat2" ...
  bashSkipArray = lib.concatMapStringsSep " " (p: ''"${p}"'') allSkipPatterns;
  # Comma-separated include list for icalBuddy's -ic flag, or empty.
  icArg = lib.optionalString (includedCalendars != [ ]) (
    " -ic " + lib.escapeShellArg (lib.concatStringsSep "," includedCalendars)
  );
in
# Next calendar event indicator via icalBuddy (homebrew, macOS-only).
# Polled on a timer.
#
# Setup:
#   1. icalBuddy is installed via homebrew (see homebrew/default.nix).
#   2. Grant Calendar permission to sketchybar (or icalBuddy itself) once via
#      System Settings → Privacy & Security → Calendars. Until then, icalBuddy
#      returns no events and the widget stays hidden.
#   3. Set `configVars.calendars.included` and `configVars.calendars.skipPatterns`
#      in nix-secrets to filter to your work + personal calendars and to drop
#      events whose titles match private/noise patterns.
#
# Behavior:
#   - Looks at events today only (`eventsToday`), future-only via `-n`.
#   - Iterates up to 10 candidates; renders the FIRST one not matching any skip
#     pattern. Lets you e.g. filter "focus time" without losing the real next
#     meeting that follows it.
#   - Color/icon escalation by time-to-start:
#       in 16+ minutes →  white
#       in <=15 min   →  amber
#       in progress   →  red "NOW: ..."
#       ended         →  hidden
writeShellScript "sketchybar_calendar" ''
  # Locate icalBuddy. Homebrew puts it at /opt/homebrew/bin on Apple Silicon
  # and /usr/local/bin on Intel. Hide cleanly if not installed yet.
  ICAL_BUDDY=""
  for candidate in /opt/homebrew/bin/icalBuddy /usr/local/bin/icalBuddy; do
    if [ -x "$candidate" ]; then
      ICAL_BUDDY="$candidate"
      break
    fi
  done
  if [ -z "$ICAL_BUDDY" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
  fi

  # Default + user-supplied skip patterns, baked in at Nix build time.
  SKIP_PATTERNS=( ${bashSkipArray} )

  should_skip() {
    local title="$1"
    local p
    for p in "''${SKIP_PATTERNS[@]}"; do
      [ -z "$p" ] && continue
      if printf '%s' "$title" | grep -qiF "$p"; then
        return 0
      fi
    done
    return 1
  }

  # Query up to 10 future events today. -ic filters to allowed calendars (if set).
  # -b "•" puts a bullet before each event title so we can split the output.
  RAW=$("$ICAL_BUDDY" \
    -n -nc -ea -nrd \
    -b "•"${icArg} \
    -po "title,datetime" \
    -tf "%H:%M" \
    -df "%Y-%m-%d" \
    -li 10 \
    eventsToday 2>/dev/null)

  if [ -z "$RAW" ] || printf '%s' "$RAW" | grep -qi "no events"; then
    sketchybar --set "$NAME" drawing=off
    exit 0
  fi

  NOW_EPOCH=$(/bin/date +%s)

  render_event() {
    local title="$1"
    local dt_line="$2"
    local start_time end_time start_date

    start_time=$(printf '%s' "$dt_line" | grep -oE '[0-9]{2}:[0-9]{2}' | sed -n '1p')
    end_time=$(printf '%s'   "$dt_line" | grep -oE '[0-9]{2}:[0-9]{2}' | sed -n '2p')
    start_date=$(printf '%s' "$dt_line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)

    # icalBuddy omits the date for events in a single-day query window
    # (when `eventsToday` returns only today's events). Fall back to today.
    [ -z "$start_date" ] && start_date=$(/bin/date +%Y-%m-%d)

    [ -z "$start_time" ] && return 1

    local start_epoch
    start_epoch=$(/bin/date -j -f "%Y-%m-%d %H:%M" "$start_date $start_time" +%s 2>/dev/null || echo "")
    [ -z "$start_epoch" ] && return 1

    local delta_min=$(( (start_epoch - NOW_EPOCH) / 60 ))

    # Truncate long titles
    if [ ''${#title} -gt 25 ]; then
      title="''${title:0:22}..."
    fi

    # Color scheme matches the aerospace_mode widget:
    #   normal:  no bg, white text/icon         (matches clock / battery / cpu)
    #   <=15min: amber bg, black text           (matches ALTER mode)
    #   in-now:  red bg, white text             (matches NOW emphasis)
    # Label color is always readable against its background.
    if [ "$delta_min" -le 0 ]; then
      # Already started — show as NOW only if still in progress.
      local end_epoch=""
      if [ -n "$end_time" ]; then
        end_epoch=$(/bin/date -j -f "%Y-%m-%d %H:%M" "$start_date $end_time" +%s 2>/dev/null || echo "")
      fi
      if [ -n "$end_epoch" ] && [ "$end_epoch" -gt "$NOW_EPOCH" ]; then
        sketchybar --set "$NAME" drawing=on \
          icon="󰃭" label="NOW: $title" \
          icon.color=0xffffffff label.color=0xffffffff \
          background.drawing=on \
          background.color=0xffcc4444 \
          background.corner_radius=5 \
          background.height=23
        return 0
      fi
      return 1  # ended; try next candidate
    elif [ "$delta_min" -le 15 ]; then
      sketchybar --set "$NAME" drawing=on \
        icon="󰃭" label="''${start_time} $title (''${delta_min}m)" \
        icon.color=0xff000000 label.color=0xff000000 \
        background.drawing=on \
        background.color=0xffe09000 \
        background.corner_radius=5 \
        background.height=23
      return 0
    else
      sketchybar --set "$NAME" drawing=on \
        icon="󰃭" label="''${start_time} $title" \
        icon.color=0xffffffff label.color=0xffffffff \
        background.drawing=off
      return 0
    fi
  }

  # Walk the events. Each event begins with a line starting with "•".
  current_title=""
  current_dt_line=""
  found=0

  try_current() {
    [ -z "$current_title" ] && return 1
    [ -z "$current_dt_line" ] && return 1
    if should_skip "$current_title"; then
      return 1
    fi
    render_event "$current_title" "$current_dt_line"
  }

  while IFS= read -r line; do
    case "$line" in
      "•"*)
        if [ -n "$current_title" ]; then
          if try_current; then found=1; break; fi
        fi
        # strip leading "• " (or just "•")
        current_title="''${line#•}"
        current_title="''${current_title# }"
        current_dt_line=""
        ;;
      *)
        # Capture the first line after the title that looks like a time line.
        # icalBuddy emits either "YYYY-MM-DD at HH:MM - HH:MM" (multi-day
        # window) or just "HH:MM - HH:MM" (single-day window). Match on time.
        if [ -z "$current_dt_line" ] && [ -n "$current_title" ] \
           && printf '%s' "$line" | grep -qE '[0-9]{2}:[0-9]{2}'; then
          current_dt_line="$line"
        fi
        ;;
    esac
  done <<< "$RAW"

  # Try the final accumulated event
  if [ "$found" -eq 0 ] && [ -n "$current_title" ]; then
    try_current && found=1
  fi

  if [ "$found" -eq 0 ]; then
    sketchybar --set "$NAME" drawing=off
  fi
''
