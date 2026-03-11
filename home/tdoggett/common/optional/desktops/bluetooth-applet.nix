{ ... }:
{
  # Blueman applet for the system tray — provides GUI for connecting/managing bluetooth devices.
  # Only import on hosts with bluetooth hardware (see hosts/common/optional/bluetooth.nix).
  services.blueman-applet.enable = true;
}
