{
  pkgs,
  config,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Toggle the litra-autotoggle launchd agent. Click while active → bootout
# the service and turn the light off. Click while suspended → bootstrap
# the agent's plist to restart it.
#
# The brief sleep before `litra off` exists because the daemon may still
# be running for a moment after bootout; without it, the daemon races us
# and turns the light back on before responding to its own shutdown.
writeShellScript "sketchybar_litra_click" ''
  UID_NUM="''${UID:-$(id -u)}"
  SERVICE="gui/''${UID_NUM}/org.nixos.litra-autotoggle"
  PLIST="$HOME/Library/LaunchAgents/org.nixos.litra-autotoggle.plist"

  # Locate the `litra` binary.
  LITRA_BIN="${config.homebrew.prefix}/bin/litra"

  if /bin/launchctl print "$SERVICE" >/dev/null 2>&1; then
    /bin/launchctl bootout "$SERVICE" 2>/dev/null
    sleep 0.3
    [ -n "$LITRA_BIN" ] && "$LITRA_BIN" off >/dev/null 2>&1 || true
  else
    if [ -f "$PLIST" ]; then
      /bin/launchctl bootstrap "gui/''${UID_NUM}" "$PLIST" 2>/dev/null
    fi
  fi

  sketchybar --trigger litra_state_changed
''
