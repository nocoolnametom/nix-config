{ pkgs, lib, ... }:
{
  services.syncthing = {
    enable = lib.mkDefault true;
    tray.enable = lib.mkDefault true;
  };
}