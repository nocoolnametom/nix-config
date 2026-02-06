{ config, lib, configVars, pkgs, ... }:

# WireGuard tunnel between bombadil and estel
# This provides a dedicated, always-on VPN tunnel for critical SSH access
# Separate from Tailscale mesh networking

let
  hostName = config.networking.hostName;
  isBombadil = hostName == configVars.networking.external.bombadil.name;
  isEstel = hostName == configVars.networking.subnets.estel.name;
in
{
  config = lib.mkIf (isBombadil || isEstel) {
    # SOPS secrets for WireGuard private keys
    # Using wireguard/homelab/${hostName}/privatekey structure
    sops.secrets."wireguard/homelab/${hostName}/privatekey" = {
      mode = "0400";
    };

    # Enable WireGuard kernel module
    boot.extraModulePackages = [ config.boot.kernelPackages.wireguard ];

    # WireGuard network interface
    networking.wireguard.interfaces.wg-bombadil-estel = lib.mkMerge [
      # Common config for both sides
      {
        privateKeyFile = config.sops.secrets."wireguard/homelab/${hostName}/privatekey".path;
      }

      # Bombadil-specific config (server side)
      (lib.mkIf isBombadil {
        ips = [ "${configVars.networking.wireguard.bombadil.ip}/24" ];
        listenPort = configVars.networking.wireguard.port;

        peers = [{
          # estel
          publicKey = configVars.networking.wireguard.estel.publicKey;
          allowedIPs = [ "${configVars.networking.wireguard.estel.ip}/32" ];
        }];
      })

      # Estel-specific config (client side)
      (lib.mkIf isEstel {
        ips = [ "${configVars.networking.wireguard.estel.ip}/24" ];

        peers = [{
          # bombadil
          publicKey = configVars.networking.wireguard.bombadil.publicKey;
          endpoint = "${configVars.networking.external.bombadil.ip}:${toString configVars.networking.wireguard.port}";
          allowedIPs = [ "${configVars.networking.wireguard.bombadil.ip}/32" ];
          persistentKeepalive = 25; # Keep connection alive through NAT
        }];
      })
    ];

    # Firewall rules
    networking.firewall = lib.mkMerge [
      # Bombadil needs to accept incoming WireGuard
      (lib.mkIf isBombadil {
        allowedUDPPorts = [ configVars.networking.wireguard.port ];
      })
      # Both sides trust the WireGuard interface
      {
        trustedInterfaces = [ "wg-bombadil-estel" ];
      }
    ];
  };
}
