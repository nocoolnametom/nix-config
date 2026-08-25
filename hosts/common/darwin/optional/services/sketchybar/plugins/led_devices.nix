{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# LED alert device status + hover-detail handler.
#
# Single script handles all events:
#   - mouse.entered / mouse.exited → toggle per-device label
#   - default (timer or boot)       → probe USB HID tree, update icon + label
#
# The icon is a plain digit showing how many device *types* are currently
# detected. No color-coded health state is shown because the set of "expected"
# devices changes by context: the blink(1) is on the home Thunderbolt hub,
# the Luxafor Flag travels, and the BlinkStick Square and Kuando Busylight
# come and go via the KVM. A raw count lets the user decide what's normal
# for the current situation without the widget imposing a judgement.
#
# Detection uses macOS `hidutil list`: a read-only snapshot of connected HID
# devices (one row per HID interface). No side effects — never opens or drives
# any device. Update frequency is set to 10s in the bar config so plugging/
# unplugging registers quickly during troubleshooting.
#
# Note: hidutil reports one row per HID *interface*, not per physical device.
# A device that presents multiple HID interfaces will produce multiple rows.
# For the purpose of showing "something is connected" this is fine; count
# values in the hover label may read higher than physical device count.
writeShellScript "sketchybar_led_devices" ''
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

  # Snapshot connected HID devices once; all three probes read from this string.
  HID_LIST=$(/usr/bin/hidutil list 2>/dev/null)

  # BlinkStick Square: VID=0x20a0 (Agner Engineering).
  SQUARE_COUNT=$(echo "$HID_LIST" | grep -ic "0x20a0" || echo 0)

  # ThingM blink(1) mk2/mk3: VID=0x27b8 (ThingM Corporation).
  BLINK1_COUNT=$(echo "$HID_LIST" | grep -ic "0x27b8" || echo 0)

  # Luxafor Flag (any gen): match by product name because VID 0x04d8 belongs
  # to Microchip Technology and is shared by many unrelated HID controllers.
  FLAG_COUNT=$(echo "$HID_LIST" | grep -ic "luxafor" || echo 0)

  # Kuando Busylight (Omega, Alpha, UC, etc.): VID=0x27bb (Plenom A/S).
  KUANDO_COUNT=$(echo "$HID_LIST" | grep -ic "0x27bb" || echo 0)

  # TYPES_CONNECTED is the number of distinct device types with at least one
  # unit detected. This is what the digit icon displays — one type = one count,
  # regardless of how many physical units of that type are present.
  TYPES_CONNECTED=0
  [ "$SQUARE_COUNT" -gt 0 ] && TYPES_CONNECTED=$(( TYPES_CONNECTED + 1 ))
  [ "$BLINK1_COUNT" -gt 0 ] && TYPES_CONNECTED=$(( TYPES_CONNECTED + 1 ))
  [ "$FLAG_COUNT"   -gt 0 ] && TYPES_CONNECTED=$(( TYPES_CONNECTED + 1 ))
  [ "$KUANDO_COUNT" -gt 0 ] && TYPES_CONNECTED=$(( TYPES_CONNECTED + 1 ))

  # Build per-device strings. Show count suffix only when more than one
  # interface row was detected for a type (e.g. "✓ Luxafor Flag ×2").
  if [ "$SQUARE_COUNT" -eq 0 ]; then
    SQUARE_STR="✗ BlinkStick Square"
  elif [ "$SQUARE_COUNT" -eq 1 ]; then
    SQUARE_STR="✓ BlinkStick Square"
  else
    SQUARE_STR="✓ BlinkStick Square ×''${SQUARE_COUNT}"
  fi

  if [ "$BLINK1_COUNT" -eq 0 ]; then
    BLINK1_STR="✗ blink(1)"
  elif [ "$BLINK1_COUNT" -eq 1 ]; then
    BLINK1_STR="✓ blink(1)"
  else
    BLINK1_STR="✓ blink(1) ×''${BLINK1_COUNT}"
  fi

  if [ "$FLAG_COUNT" -eq 0 ]; then
    FLAG_STR="✗ Luxafor Flag"
  elif [ "$FLAG_COUNT" -eq 1 ]; then
    FLAG_STR="✓ Luxafor Flag"
  else
    FLAG_STR="✓ Luxafor Flag ×''${FLAG_COUNT}"
  fi

  if [ "$KUANDO_COUNT" -eq 0 ]; then
    KUANDO_STR="✗ Kuando Busylight"
  elif [ "$KUANDO_COUNT" -eq 1 ]; then
    KUANDO_STR="✓ Kuando Busylight"
  else
    KUANDO_STR="✓ Kuando Busylight ×''${KUANDO_COUNT}"
  fi

  # Icon is the count of distinct device types detected. White — no health
  # semantics — because the expected set varies by context (home hub vs. travel).
  sketchybar --set "$NAME" \
    icon="''${TYPES_CONNECTED}" \
    icon.color=0xffffffff \
    label="''${SQUARE_STR}  |  ''${BLINK1_STR}  |  ''${FLAG_STR}  |  ''${KUANDO_STR}"
''
