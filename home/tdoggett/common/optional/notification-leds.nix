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
{
  services.notification-leds = {
    enable = true;
    sources = {
      slack = {
        color = "red";
        devices = [
          "flag"
          "blink1"
        ];
        # Longer for "blink until I read it" continuous pattern — the
        # polling source re-issues every ~2-3s while unread > 0.
        repeats = 30;
      };
      email = {
        color = "blue";
        devices = [ "flag" ];
      };
      calendar = {
        color = "yellow";
        devices = [ "blink1" ];
      };
    };
  };
}
