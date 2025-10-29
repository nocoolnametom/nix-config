{ pkgs, lib, ... }:
{
  services.tailscale.enable = lib.mkDefault true;
  services.tailscale.package = lib.mkDefault pkgs.unstable.tailscale;
}
