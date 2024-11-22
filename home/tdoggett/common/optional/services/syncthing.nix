{ pkgs, lib, ... }:
{
  services.syncthing = {
    enable = lib.mkDefault true;
  };
}
