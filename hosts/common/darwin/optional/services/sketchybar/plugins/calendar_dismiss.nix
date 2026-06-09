{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Click handler for the [X] button that sits to the left of the calendar widget.
# Lets you dismiss a NOW-active calendar event when it ends early (e.g. a 30-min
# meeting that wraps in 10) so the widget moves on to the next one.
#
# State files (both in /tmp, no persistence across reboots needed):
#   /tmp/sketchybar-calendar-current.txt    — the currently-displayed event's ID,
#                                             written by the calendar widget on
#                                             each render of a NOW event.
#   /tmp/sketchybar-calendar-dismissed.txt  — one event ID per line; the calendar
#                                             widget skips any matching entry.
#
# Event ID format: "YYYY-MM-DD|HH:MM|Title". The date prefix lets the calendar
# widget auto-prune yesterday's dismissals on its next tick.
#
# Triggering a refresh: emits the `calendar_dismissed` custom event, which the
# calendar widget subscribes to — that re-runs its script immediately and the
# bar shows the next event (or hides) within a beat.
writeShellScript "sketchybar_calendar_dismiss" ''
  DISMISS_FILE="/tmp/sketchybar-calendar-dismissed.txt"
  CURRENT_FILE="/tmp/sketchybar-calendar-current.txt"

  if [ ! -s "$CURRENT_FILE" ]; then
    exit 0
  fi

  EVENT_ID="$(cat "$CURRENT_FILE")"
  [ -z "$EVENT_ID" ] && exit 0

  # Append (the calendar widget dedups on read via grep -qxF).
  printf '%s\n' "$EVENT_ID" >> "$DISMISS_FILE"

  # Force-hide the button immediately so the user gets instant feedback while
  # the calendar widget repaints.
  sketchybar --set "$NAME" drawing=off

  # Re-run the calendar widget right now.
  sketchybar --trigger calendar_dismissed
''
