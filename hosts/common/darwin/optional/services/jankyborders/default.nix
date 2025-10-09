{ lib, ... }:
{
  services.jankyborders.enable = lib.mkDefault true;
  services.jankyborders.active_color = lib.mkDefault "0xffe1e3e4";
  services.jankyborders.inactive_color = lib.mkDefault "0xff494d64";
}
