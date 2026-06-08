{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Current weather via a user-created macOS Shortcut named "Sketchybar Weather".
# The Shortcut uses Apple's "Get Current Weather" action (WeatherKit + Location
# Services), so it matches the source of the menubar Weather widget. No
# third-party API or credentials needed.
#
# One-time setup (Shortcuts.app):
#   1. Open Shortcuts.app → "+" → New Shortcut, name it "Sketchybar Weather"
#   2. Action: "Get Current Weather"           (uses current location)
#   3. Action: "Get Details of Weather Conditions" → Temperature
#   4. Action: "Get Details of Weather Conditions" → Conditions
#   5. Action: "Text"  →  Type:  ⟨Temperature⟩ ⟨Conditions⟩
#   6. Action: "Stop and output"  →  the Text
#   7. First run will prompt for Location permission — grant it.
#
# Output of the Shortcut should be a single line like:  "72°F Mostly Sunny"
# If the Shortcut isn't present yet, the widget hides silently.
writeShellScript "sketchybar_weather" ''
  # First: does the Shortcut exist at all? If not, show a visible "setup
  # needed" state instead of hiding silently. The click handler picks up
  # this state and offers a setup dialog.
  if ! /usr/bin/shortcuts list 2>/dev/null | grep -qFx "Sketchybar Weather"; then
    sketchybar --set "$NAME" drawing=on \
      icon="󰒓" \
      label="Setup weather" \
      icon.color=0xff000000 \
      label.color=0xff000000 \
      icon.font="SFProDisplay Nerd Font:Heavy:14.0" \
      label.font="SFProDisplay Nerd Font:Heavy:14.0" \
      background.drawing=on \
      background.color=0xffe09000 \
      background.corner_radius=5 \
      background.height=23
    exit 0
  fi

  OUTPUT=$(/usr/bin/shortcuts run "Sketchybar Weather" 2>/dev/null | head -1 | sed 's/[[:space:]]*$//')

  if [ -z "$OUTPUT" ]; then
    # Shortcut is defined but returned nothing — most often Location
    # permission hasn't been granted yet. Show a distinct error state.
    sketchybar --set "$NAME" drawing=on \
      icon="󰀦" \
      label="Weather error" \
      icon.color=0xffff8800 \
      label.color=0xffff8800 \
      background.drawing=off
    exit 0
  fi

  # Pick a nerd-font weather icon by matching condition keywords in the
  # Shortcut's output. Apple's condition strings are reasonably stable.
  icon="󰖕"  # cloudy default
  shopt -s nocasematch
  case "$OUTPUT" in
    *sunny*|*clear*)              icon="󰖙" ;;
    *partly*cloud*|*mostly*sunny*) icon="󰖕" ;;
    *cloud*|*overcast*)           icon="󰖐" ;;
    *thunder*|*storm*)            icon="󰖓" ;;
    *rain*|*drizzle*|*shower*)    icon="󰖖" ;;
    *snow*|*sleet*|*flurr*)       icon="󰼶" ;;
    *fog*|*mist*|*haze*|*smoke*)  icon="󰖑" ;;
    *wind*)                       icon="󰖝" ;;
  esac
  shopt -u nocasematch

  sketchybar --set "$NAME" drawing=on icon="$icon" label="$OUTPUT" \
    icon.color=0xffffffff label.color=0xffffffff \
    background.drawing=off
''
