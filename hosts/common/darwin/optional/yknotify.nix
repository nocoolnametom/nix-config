{ lib, ... }:
{
  services.yknotify.enable = lib.mkDefault true;
  services.yknotify.sound = lib.mkDefault "Sosumi";
}
