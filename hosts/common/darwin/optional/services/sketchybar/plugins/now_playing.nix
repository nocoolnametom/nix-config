{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Now-playing display — polls Apple Music + Spotify via AppleScript.
#
# Background: originally subscribed to sketchybar's built-in
# `media_change` event, which uses the macOS MediaRemote private
# framework. As of macOS 26 (Tahoe) Apple has hardened MediaRemote and
# sketchybar can no longer observe playback state through it — events
# arrive as null even while music is playing. AppleScript automation
# still works.
#
# First-run permission: macOS will prompt sketchybar for AppleScript
# automation access to Music.app (and Spotify.app, if installed) the
# first time this script runs. Grant via the popup or via:
#   System Settings → Privacy & Security → Automation → sketchybar
# Until granted, queries return empty and the widget stays hidden.
#
# Polled on a timer (update_freq=5 in the bar config). Each poll spawns
# at most two osascript subprocesses — one combined query per app.
#
# Compact-on-built-in: when /tmp/sketchybar-builtin-display is non-empty
# (i.e. the built-in is attached), the widget renders the music icon
# only — the track label is hidden until the user hovers, at which
# point the full `Artist — Title` label appears.
writeShellScript "sketchybar_now_playing" ''
  flag_file="/tmp/sketchybar-builtin-display"
  if [ -s "$flag_file" ]; then
    COMPACT=1
  else
    COMPACT=0
  fi

  # Hover handlers only toggle label.drawing — the label content is set
  # by the regular poll below. In non-compact mode the label is always
  # drawn so hover is a no-op.
  case "$SENDER" in
    mouse.entered)
      if [ "$COMPACT" = "1" ]; then
        sketchybar --set "$NAME" label.drawing=on
      fi
      exit 0
      ;;
    mouse.exited)
      if [ "$COMPACT" = "1" ]; then
        sketchybar --set "$NAME" label.drawing=off
      fi
      exit 0
      ;;
  esac

  query_app() {
    local app="$1"
    /usr/bin/osascript -e "
      tell application \"System Events\"
        if not (exists process \"$app\") then return \"\"
      end tell
      tell application \"$app\"
        try
          if player state is playing then
            return (name of current track) & \"|\" & (artist of current track)
          end if
        end try
        return \"\"
      end tell
    " 2>/dev/null
  }

  RESULT=""
  for app in "Music" "Spotify"; do
    RESULT=$(query_app "$app")
    if [ -n "$RESULT" ]; then break; fi
  done

  if [ -z "$RESULT" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
  fi

  TITLE="''${RESULT%%|*}"
  ARTIST="''${RESULT##*|}"

  if [ -n "$ARTIST" ] && [ "$ARTIST" != "$TITLE" ]; then
    LABEL="$ARTIST — $TITLE"
  else
    LABEL="$TITLE"
  fi

  if [ ''${#LABEL} -gt 35 ]; then
    LABEL="''${LABEL:0:32}..."
  fi

  if [ "$COMPACT" = "1" ]; then
    sketchybar --set "$NAME" drawing=on icon="󰎈" label="$LABEL" label.drawing=off
  else
    sketchybar --set "$NAME" drawing=on icon="󰎈" label="$LABEL" label.drawing=on
  fi
''
