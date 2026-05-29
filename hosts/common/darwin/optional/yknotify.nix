{ lib, ... }:
{
  services.yknotify.enable = lib.mkDefault true;
}
