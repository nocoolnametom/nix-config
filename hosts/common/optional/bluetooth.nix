{ lib, ... }:
{
  hardware.bluetooth.enable = lib.mkDefault true;
  hardware.bluetooth.powerOnBoot = lib.mkDefault true;
  services.blueman.enable = lib.mkDefault true;
}
