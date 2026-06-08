{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Corporate VPN client status. Polled on a timer (update_freq). Hidden when
# the CLI isn't present at the expected path (see VPN_CLI below).
#
# `vpn status` output has MULTIPLE `state:` lines — typically one per tunnel
# plus a leading "Unknown" for the management subsystem. We treat the host
# as connected if any state line says "Connected".
writeShellScript "sketchybar_vpn" ''
  VPN_CLI="/opt/cisco/secureclient/bin/vpn"

  if [ ! -x "$VPN_CLI" ]; then
    sketchybar --set "$NAME" drawing=off
    exit 0
  fi

  RAW=$("$VPN_CLI" status 2>/dev/null)

  if echo "$RAW" | grep -qiE "state:[[:space:]]*Connected"; then
    STATUS=Connected
  elif echo "$RAW" | grep -qiE "state:[[:space:]]*Disconnected"; then
    STATUS=Disconnected
  elif echo "$RAW" | grep -qiE "state:[[:space:]]*(Connecting|Reconnecting|Disconnecting)"; then
    STATUS=$(echo "$RAW" | grep -iE "state:[[:space:]]*(Connecting|Reconnecting|Disconnecting)" \
      | head -1 | awk -F'state:' '{print $2}' | awk '{print $1}')
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
    *)
      # Transient: Connecting, Reconnecting, Disconnecting
      sketchybar --set "$NAME" \
        drawing=on \
        icon="󰦞" \
        label="$STATUS" \
        icon.color=0xffe09000 \
        label.color=0xffe09000
      ;;
  esac
''
