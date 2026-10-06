{
  config,
  lib,
  configVars,
  ...
}:

# WireGuard tunnel between bombadil (VPS) and estel (homelab).
# Provides a dedicated, always-on VPN link for SNI-routed service traffic.
# The only tunnel between the VPS and the homelab (Tailscale was removed
# 2026-10-06; it had never been logged in on any of the servers).

let
  hostName = config.networking.hostName;
  isBombadil = hostName == configVars.networking.external.bombadil.name;
  isEstel = hostName == configVars.networking.subnets.estel.name;
in
{
  config = lib.mkIf (isBombadil || isEstel) {
    sops.secrets."wireguard/homelab/${hostName}/privatekey" = {
      mode = "0400";
    };

    networking.wireguard.interfaces.wg-homelab = lib.mkMerge [
      {
        privateKeyFile = config.sops.secrets."wireguard/homelab/${hostName}/privatekey".path;
      }

      # Bombadil (server): accepts inbound from estel
      (lib.mkIf isBombadil {
        ips = [ "${configVars.networking.wireguard.bombadil.ip}/24" ];
        listenPort = configVars.networking.wireguard.port;
        peers = [
          {
            publicKey = configVars.networking.wireguard.estel.publicKey;
            allowedIPs = [ "${configVars.networking.wireguard.estel.ip}/32" ];
          }
        ];
      })

      # Estel (client): outbound to bombadil
      (lib.mkIf isEstel {
        ips = [ "${configVars.networking.wireguard.estel.ip}/24" ];
        peers = [
          {
            publicKey = configVars.networking.wireguard.bombadil.publicKey;
            endpoint = "${configVars.networking.external.bombadil.ip}:${toString configVars.networking.wireguard.port}";
            allowedIPs = [ "${configVars.networking.wireguard.bombadil.ip}/32" ];
            persistentKeepalive = 25;
          }
        ];
      })
    ];

    networking.firewall = lib.mkMerge [
      (lib.mkIf isBombadil {
        allowedUDPPorts = [ configVars.networking.wireguard.port ];
      })
      {
        trustedInterfaces = [ "wg-homelab" ];
      }
    ];
  };
}
