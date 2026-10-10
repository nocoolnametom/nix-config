###############################################################################
#
#  ups-server — NUT server for the cabinet's CyberPower CP1500
#
#  feanor is the only machine with a USB connection to the UPS, so it polls the
#  device and re-serves the status on the LAN. estel subscribes to it through
#  hosts/common/optional/services/ups-client.nix and shuts down off the same
#  battery.
#
#  Everything on this UPS sits in the one cabinet: feanor, estel, the mesh hub
#  and the switch. The network gear being on battery too is what makes the
#  netclient half trustworthy — estel can still reach upsd here after mains
#  drops, which is otherwise the standard way NUT-over-network setups fail
#  (the client loses its path to the server at the exact moment it matters).
#
#  Hardware: CyberPower CP1500 AVR, USB 0764:0501, /dev/hidraw0, usbhid-ups.
#
#  Two things feanor's ephemeral root would normally complicate, both already
#  handled by the module:
#    - /var/lib/nut and /var/state/ups are recreated by its tmpfiles rules on
#      every boot, so nothing needs persisting.
#    - the driver runs as root (upsdrvctl -u root), so /dev/hidraw0 is readable
#      without shipping a udev rule.
#
#  Shutdown threshold: left at the UPS's own low-battery flag for now. feanor
#  is not quick to stop (16 TiB btrfs, Postgres, Immich, four arion stacks), so
#  once this is running, read `upsc cp1500` for the real battery.runtime and
#  ups.load and raise the trigger if the measured margin is too thin.
#
###############################################################################

{
  config,
  configVars,
  ...
}:

{
  # Read by PID 1 through LoadCredential before upsd and upsmon drop
  # privileges, so the default root-only ownership is correct here.
  sops.secrets."homelab/ups-daemon-key" = { };

  power.ups = {
    enable = true;
    mode = "netserver";
    openFirewall = true; # TCP 3493, for estel's upsmon

    ups.cp1500 = {
      driver = "usbhid-ups";
      # usbhid-ups finds the device by USB id rather than a serial port, but
      # ups.conf still requires the directive; "auto" is the documented value.
      port = "auto";
      description = "CyberPower CP1500 AVR (homelab cabinet)";
    };

    # Loopback for feanor's own upsmon and for interactive upsc; the LAN
    # address for estel.
    upsd.listen = [
      { address = "127.0.0.1"; }
      { address = configVars.networking.subnets.feanor.ip; }
    ];

    # Split accounts so estel holds only secondary rights and cannot issue the
    # primary-only commands (FSD above all) that would force this host down.
    # Both read the same secret today; give them separate ones if that stops
    # being good enough.
    users = {
      upsmon-primary = {
        upsmon = "primary";
        passwordFile = config.sops.secrets."homelab/ups-daemon-key".path;
      };
      upsmon-secondary = {
        upsmon = "secondary";
        passwordFile = config.sops.secrets."homelab/ups-daemon-key".path;
      };
    };

    # `system` defaults to the attribute name, which is the local UPS.
    upsmon.monitor.cp1500 = {
      user = "upsmon-primary";
      type = "primary";
    };
  };
}
