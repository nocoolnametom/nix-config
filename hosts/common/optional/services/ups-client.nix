###############################################################################
#
#  ups-client — shut down off feanor's CyberPower CP1500
#
#  estel shares the cabinet UPS with feanor but has no USB connection to it, so
#  it subscribes to feanor's upsd and halts when that reports the battery is
#  low. Server half: hosts/common/optional/services/ups-server.nix.
#
#  The switch and the mesh hub are on the same UPS, so the network path to
#  feanor's upsd outlives the outage that triggers all of this.
#
#  netclient mode does not start upsd — the module defaults upsd.enable to true
#  only for standalone and netserver — so this host runs upsmon alone.
#
###############################################################################

{
  config,
  configVars,
  ...
}:

{
  # Same secret as the server; read by PID 1 through LoadCredential.
  sops.secrets."homelab/ups-daemon-key" = { };

  power.ups = {
    enable = true;
    mode = "netclient";

    # Keep the attribute name plain and set `system` explicitly: the module
    # derives a systemd credential id (upsmon_password_<name>) from the
    # attribute name, and an "@" or a dot from the host part does not belong
    # in one.
    upsmon.monitor.cp1500 = {
      system = "cp1500@${configVars.networking.subnets.feanor.ip}";
      user = "upsmon-secondary";
      passwordFile = config.sops.secrets."homelab/ups-daemon-key".path;
      type = "secondary";
    };
  };
}
