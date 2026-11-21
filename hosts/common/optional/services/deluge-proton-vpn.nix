# Run Deluge inside the Proton VPN namespace (see ../proton-vpn-netns.nix for
# the shared setup, secrets and troubleshooting commands). Import alongside
# ./deluge.nix.
{
  config,
  pkgs,
  ...
}:
let
  delugeConfigDir = "${config.services.deluge.dataDir}/.config/deluge";
in
{
  imports = [ ../proton-vpn-netns.nix ];

  services.proton-vpn-netns = {
    # Proton only allows torrent traffic on its P2P servers.
    p2p = true;

    confinedServices = [ "deluged" ];
    # delugeweb, Flood and the *arr apps stay on the host and reach the daemon here.
    forwardPorts = [ config.services.deluge.config.daemon_port ];

    # Point Deluge's listen port at the port Proton forwards to us, so peers can
    # connect in. Runs as the deluge user so deluge-console's own files in the
    # config dir stay owned by deluge; it authenticates as `localclient`.
    portForwarding.enable = true;
    portForwarding.hookPath = [
      config.services.deluge.package
      pkgs.util-linux
      pkgs.gnugrep
    ];
    portForwarding.hook = ''
      out=$(runuser -u ${config.services.deluge.user} -- \
        deluge-console -c ${delugeConfigDir} "config --set listen_ports [$PORT,$PORT]" 2>&1)
      if ! echo "$out" | grep -q "successfully updated"; then
        echo "$out"
        exit 1
      fi
    '';
  };
}
