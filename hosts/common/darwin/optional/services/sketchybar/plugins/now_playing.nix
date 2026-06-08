{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Now-playing display via sketchybar's built-in `media_change` event.
# $INFO is JSON: { title, artist, album, app, state, ... }
# Hides when nothing is playing.
writeShellScript "sketchybar_now_playing" ''
  if [ "$SENDER" != "media_change" ]; then
    # Initial load — no media event has fired yet. Stay hidden.
    sketchybar --set "$NAME" drawing=off
    exit 0
  fi

  STATE=$(echo "$INFO" | jq -r '.state // "stopped"')
  TITLE=$(echo "$INFO" | jq -r '.title // ""')
  ARTIST=$(echo "$INFO" | jq -r '.artist // ""')

  if [ "$STATE" != "playing" ] || [ -z "$TITLE" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
  fi

  if [ -n "$ARTIST" ]; then
    LABEL="$ARTIST — $TITLE"
  else
    LABEL="$TITLE"
  fi

  # Truncate to keep the bar tidy
  if [ ''${#LABEL} -gt 35 ]; then
    LABEL="''${LABEL:0:32}..."
  fi

  sketchybar --set "$NAME" drawing=on icon="󰎈" label="$LABEL"
''
