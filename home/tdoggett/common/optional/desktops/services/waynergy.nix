{ lib, ... }:
{
  services.waynergy = {
    enable = lib.mkDefault true;
    offset = lib.mkDefault 7;
    host = lib.mkDefault "192.168.0.10";
    port = lib.mkDefault 24801;
  };
}
