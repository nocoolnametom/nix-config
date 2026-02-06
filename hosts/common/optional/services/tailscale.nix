{ pkgs, lib, ... }:
{
  # Enable Tailscale mesh VPN
  services.tailscale.enable = lib.mkDefault true;
  services.tailscale.package = lib.mkDefault pkgs.unstable.tailscale;

  # Open firewall for Tailscale
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.allowedUDPPorts = [ 41641 ]; # Tailscale UDP port

  # Allow Tailscale subnet routes if needed
  # services.tailscale.useRoutingFeatures = lib.mkDefault "client";
}
