{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Netskope Client NPA (Network Private Access) tunnel status. Polled on a
# timer (update_freq). Hidden when the CLI isn't present at the expected
# path (see VPN_CLI below).
#
# Display: colored shield icon only by default (color = state). Hovering
# the widget reveals the descriptive label ("VPN" when connected, blank
# when disconnected). Single script handles both polling and hover events;
# the polling branch always sets the label text so it's accurate the moment
# the user hovers — only label.drawing is toggled by mouse events.
#
# `nsdiag -n` reports two lines, e.g.:
#   NPA status is Connected (User Tunnel).
#   NPA gateway IP is <ip>.
# or:
#   NPA status is Disabled.
#   NPA gateway IP is N/A.
writeShellScript "sketchybar_vpn" ''
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

  VPN_CLI="/Library/Application Support/Netskope/STAgent/nsdiag"

  if [ ! -x "$VPN_CLI" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
  fi

  RAW=$("$VPN_CLI" -n 2>/dev/null)

  if echo "$RAW" | grep -qiE "NPA status is Connected"; then
    STATUS=Connected
  else
    STATUS=Disconnected
  fi

  case "$STATUS" in
    Connected)
      sketchybar --set "$NAME" \
        drawing=on \
        icon="󰒃" \
        label="VPN" \
        icon.color=0xff44cc44 \
        label.color=0xff44cc44
      ;;
    Disconnected)
      sketchybar --set "$NAME" \
        drawing=on \
        icon="󰦞" \
        label="" \
        icon.color=0xff888888
      ;;
  esac
''
