{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# When the built-in display is attached (flag file non-empty), shows just
# the time. Hovering expands to the full date+time. When the built-in
# isn't attached, always shows the full date+time.
writeShellScript "sketchybar_clock" ''
  flag_file="/tmp/sketchybar-builtin-display"
  if [ -s "$flag_file" ]; then
    COMPACT=1
  else
    COMPACT=0
  fi

  full_label="$(date +'%a %d %b %I:%M %p')"
  compact_label="$(date +'%I:%M %p')"

  case "$SENDER" in
    mouse.entered)
      sketchybar --set "$NAME" label="$full_label"
      exit 0
      ;;
    mouse.exited)
      if [ "$COMPACT" = "1" ]; then
        sketchybar --set "$NAME" label="$compact_label"
      else
        sketchybar --set "$NAME" label="$full_label"
      fi
      exit 0
      ;;
  esac

  if [ "$COMPACT" = "1" ]; then
    sketchybar --set "$NAME" label="$compact_label"
  else
    sketchybar --set "$NAME" label="$full_label"
  fi
''
