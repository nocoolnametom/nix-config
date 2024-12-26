{ pkgs, lib, ... }:
{
  environment.systemPackages = [
    pkgs.sbctl
  ];

  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote.enable = lib.mkDefault true;
  boot.lanzaboote.pkiBundle = lib.mkDefault "/etc/secureboot";
}
