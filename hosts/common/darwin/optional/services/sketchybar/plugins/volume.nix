{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Volume + mute indicator for the currently-active output device.
# Updates on `volume_change` event (uses $INFO from sketchybar) and on any
# other trigger (initial load, system_woke) via direct osascript query.
writeShellScript "sketchybar_volume" ''
  if [ "$SENDER" = "volume_change" ]; then
    VOLUME="$INFO"
    MUTED=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)
  else
    # Initial run / system_woke — query state. One process call returns both.
    read -r VOLUME MUTED < <(osascript -e '
      set s to (get volume settings)
      return ((output volume of s) as string) & " " & ((output muted of s) as string)
    ' 2>/dev/null || echo "? false")
  fi

  # Sanity: if osascript failed in this context, label with ? rather than crash
  if ! [[ "$VOLUME" =~ ^[0-9]+$ ]]; then
    sketchybar --set "$NAME" icon="󰖁" label="?"
    exit 0
  fi

  if [ "$MUTED" = "true" ]; then
    sketchybar --set "$NAME" icon="󰖁" label="muted"
    exit 0
  fi

  case "$VOLUME" in
    [6-9][0-9]|100) ICON="󰕾" ;;
    [3-5][0-9])     ICON="󰖀" ;;
    [1-9]|[1-2][0-9]) ICON="󰕿" ;;
    0)              ICON="󰖁" ;;
    *)              ICON="󰕿" ;;
  esac

  sketchybar --set "$NAME" icon="$ICON" label="''${VOLUME}%"
''
