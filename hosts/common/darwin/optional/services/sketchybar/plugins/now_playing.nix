{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Now-playing display — polls Apple Music + Spotify via AppleScript.
#
# Originally subscribed to sketchybar's built-in `media_change` event,
# which uses the macOS MediaRemote private framework. As of macOS 26
# (Tahoe) Apple has hardened MediaRemote and sketchybar can no longer
# observe playback state through it — events: null even when music is
# playing. AppleScript automation still works.
#
# First-run permission: macOS will prompt sketchybar for AppleScript
# automation access to Music.app (and Spotify.app, if installed) the
# first time this script runs. Grant via the popup or via:
#   System Settings → Privacy & Security → Automation → sketchybar
# Until granted, queries return empty and the widget stays hidden.
#
# Polled on a timer (update_freq=5 in the bar config). Each poll spawns
# at most two osascript subprocesses — one combined query per app.
writeShellScript "sketchybar_now_playing" ''
  # Query an app for its currently-playing track via a single osascript
  # invocation. Returns "playing|<title>|<artist>" on a hit, empty otherwise.
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

  sketchybar --set "$NAME" drawing=on icon="󰎈" label="$LABEL"
''
