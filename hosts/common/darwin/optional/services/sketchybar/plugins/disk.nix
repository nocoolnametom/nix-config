{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Boot-disk free space percentage. White normally; bright red background +
# bold black text when <=10% free, to make low-disk states unmissable.
# Reads `df` capacity for `/` — on Apple Silicon the system and Data volumes
# share an APFS container, so this matches what "About This Mac" reports.
writeShellScript "sketchybar_disk" ''
  # Read both Use% and the Avail column so we can display an unambiguous
  # absolute amount (matches what `df -h` shows under "Avail") while still
  # using a percentage threshold (<=10% free) to drive the warning state.
  read -r USED_PCT AVAIL_H < <(df -h / 2>/dev/null | tail -1 | awk '{ gsub(/%/, "", $5); print $5, $4 }')

  if ! [[ "$USED_PCT" =~ ^[0-9]+$ ]]; then
    sketchybar --set "$NAME" icon="󰋊" label="?"
    exit 0
  fi
  FREE_PCT=$(( 100 - USED_PCT ))

  if [ "$FREE_PCT" -le 10 ]; then
    sketchybar --set "$NAME" \
      icon="󰋊" \
      label="$AVAIL_H" \
      icon.color=0xff000000 \
      label.color=0xff000000 \
      icon.font="SFProDisplay Nerd Font:Heavy:14.0" \
      label.font="SFProDisplay Nerd Font:Heavy:14.0" \
      background.drawing=on \
      background.color=0xffff0000 \
      background.corner_radius=5 \
      background.height=23
  else
    sketchybar --set "$NAME" \
      icon="󰋊" \
      label="$AVAIL_H" \
      icon.color=0xffffffff \
      label.color=0xffffffff \
      icon.font="SFProDisplay Nerd Font:Bold:14.0" \
      label.font="SFProDisplay Nerd Font:Semibold:14.0" \
      background.drawing=off
  fi
''
