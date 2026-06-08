{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Free-memory percentage. White normally; bright red background + bold black
# text when <=10% free, to flag memory pressure at a glance.
#
# Sums vm_stat's `free + inactive + speculative` page counts against total
# physical RAM. Matches what Activity Monitor calls "Available" memory.
writeShellScript "sketchybar_memory" ''
  TOTAL=$(sysctl -n hw.memsize 2>/dev/null)
  PAGE=$(sysctl -n hw.pagesize 2>/dev/null)
  if [ -z "$TOTAL" ] || [ -z "$PAGE" ]; then
    sketchybar --set "$NAME" icon="󰍛" label="?"
    exit 0
  fi

  # Source the three page counters from vm_stat in one shot.
  eval "$(vm_stat | awk -F: '
    /Pages free/        { gsub(/[^0-9]/,"",$2); print "FREE=" $2 }
    /Pages inactive/    { gsub(/[^0-9]/,"",$2); print "INACTIVE=" $2 }
    /Pages speculative/ { gsub(/[^0-9]/,"",$2); print "SPEC=" $2 }
  ')"

  if ! [[ "''${FREE:-}" =~ ^[0-9]+$ ]] \
     || ! [[ "''${INACTIVE:-}" =~ ^[0-9]+$ ]] \
     || ! [[ "''${SPEC:-}" =~ ^[0-9]+$ ]]; then
    sketchybar --set "$NAME" icon="󰍛" label="?"
    exit 0
  fi

  AVAIL=$(( (FREE + INACTIVE + SPEC) * PAGE ))
  FREE_PCT=$(( AVAIL * 100 / TOTAL ))

  if [ "$FREE_PCT" -le 10 ]; then
    sketchybar --set "$NAME" \
      icon="󰍛" \
      label="''${FREE_PCT}%" \
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
      icon="󰍛" \
      label="''${FREE_PCT}%" \
      icon.color=0xffffffff \
      label.color=0xffffffff \
      icon.font="SFProDisplay Nerd Font:Bold:14.0" \
      label.font="SFProDisplay Nerd Font:Semibold:14.0" \
      background.drawing=off
  fi
''
