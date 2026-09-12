{ ... }:
# Shared notification-LED config for hosts that have (or might gain) a
# Luxafor Flag 2, ThingM blink(1), or BlinkStick Square USB device. Drop
# this import into any host's home-manager config and the `notify-blink`
# wrapper becomes available with these source-to-color mappings.
#
# If a device isn't physically plugged in, calls silently fail (the
# wrapper backgrounds each device call and discards errors). So enabling
# this on every host is safe — only the host with the devices plugged in
# will actually light up.
# Devices: square, blink1, flag, busylight
let
  all = [
    "square"
    "blink1"
    "flag"
    "busylight"
  ];
in
{
  services.notification-leds = {
    enable = true;
    sources = {
      slack = {
        color = "magenta";
        devices = all;
        # Longer for "blink until I read it" continuous pattern — the
        # polling source re-issues every ~2-3s while unread > 0.
        repeats = 30;
      };
      email = {
        color = "blue";
        devices = all;
      };
      calendar = {
        color = "yellow";
        devices = all;
      };
      # Fired by slk-watcher when a Slack message matches a configured handle or
      # broadcast pattern (@here / @channel). Orange distinguishes a direct
      # mention from a generic Slack ping (red).
      slack-mention = {
        color = "orange";
        devices = all;
        repeats = 30;
      };
      # Fired by slk-watcher when a Slack message contains an urgent keyword
      # (P0, outage, etc.). Magenta makes it visually distinct from everything
      # else so it stands out even in peripheral vision.
      slack-urgent = {
        color = "red";
        devices = all;
        repeats = 30;
      };
    };
  };
}
