{ lib, ... }:
{
  services.nzbhydra2.enable = lib.mkDefault true;
  services.nzbhydra2.openFirewall = lib.mkDefault true;
}
