{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Litra-autotoggle status + hover tooltip handler.
#
# Single script handles all events the widget subscribes to:
#   - mouse.entered / mouse.exited → toggle the descriptive label
#   - litra_state_changed (custom)  → re-poll right away after a click
#   - default (timer or boot)       → query launchd, update icon + label text
#
# Active = bright yellow bulb; suspended = dim gray bulb. The label text
# is set on every poll so it's accurate the moment the user hovers; only
# its drawing state is toggled by mouse events.
writeShellScript "sketchybar_litra" ''
  case "$SENDER" in
    mouse.entered)
      sketchybar --set "$NAME" label.drawing=on
      exit 0
      ;;
    mouse.exited)
      sketchybar --set "$NAME" label.drawing=off
      exit 0
      ;;
  esac

  SERVICE="gui/''${UID:-$(id -u)}/org.nixos.litra-autotoggle"
  if /bin/launchctl print "$SERVICE" >/dev/null 2>&1; then
    sketchybar --set "$NAME" \
      icon="󰌵" \
      icon.color=0xffe5d04a \
      label="Auto Camera Light: On"
  else
    sketchybar --set "$NAME" \
      icon="󰹏" \
      icon.color=0xff888888 \
      label="Auto Camera Light: Off"
  fi
''
