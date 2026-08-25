{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Click handler: send a quick 3-rep green blink to all connected LED devices
# as a "system is alive" test. Runs notify-blink in the background so the
# click returns immediately without blocking the bar.
#
# notify-blink is installed by home-manager into ~/.nix-profile/bin/ —
# it isn't in the system PATH that sketchybar inherits from launchd, so
# this script looks it up via the user's profile rather than via `command -v`.
writeShellScript "sketchybar_led_devices_click" ''
  NOTIFY_BLINK="$HOME/.nix-profile/bin/notify-blink"
  if [ -x "$NOTIFY_BLINK" ]; then
    "$NOTIFY_BLINK" green 3 200 &
  fi
''
