{
  # Enable control of Luxafor Flag (and Flag 2) by non-root users.
  # VID/PID 04d8:f372 covers the USB Flag and its BT variant. If a
  # Flag 2 ever ships with a different PID, add a second rule here.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="04d8", ATTRS{idProduct}=="f372", MODE="0666"
    KERNEL=="hidraw*", ATTRS{idVendor}=="04d8", ATTRS{idProduct}=="f372", MODE="0666"
  '';
}
