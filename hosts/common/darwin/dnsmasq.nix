{ lib, inputs, ... }:
{
  services.dnsmasq.enable = lib.mkDefault true; # Find out if we want this as a service or if teleport runs it manually
  services.dnsmasq.addresses = inputs.nix-secrets.networking.workDnsmasq.addresses;
}
