{ config, ... }:
{
  # Per-User VPN Setup
  sops.secrets."proton-vpn/${config.networking.hostname}/cert" = { };
  sops.secrets."proton-vpn/${config.networking.hostname}/tls-auth" = { };
  sops.secrets."proton-vpn/${config.networking.hostname}/credentials" = { };
  services.per-user-vpn.enable = true;
  services.per-user-vpn.servers."protonvpn" = {
    certificate = "${builtins.toString config.sops.secrets."proton-vpn/${config.networking.hostname}/cert".path}";
    tls-file = "${builtins.toString config.sops.secrets."proton-vpn/${config.networking.hostname}/tls-auth".path}";
    credentialsFile = "${builtins.toString config.sops.secrets."proton-vpn/${config.networking.hostname}/credentials".path}";
    mark = "0x1";
    protocol = "udp";
    remotes = [
      "node-us-118.protonvpn.net 1194"
      "node-us-118.protonvpn.net 5060"
      "node-us-118.protonvpn.net 4569"
      "node-us-118.protonvpn.net 51820"
      "node-us-118.protonvpn.net 80"
    ];

    routeTableId = 42;
    users = [
      config.services.transmission.user
      config.services.deluge.user
    ];
  };
  networking.firewall.allowedUDPPorts = [ 1194 5060 4569 51820 80 ];
}
