{ pkgs, lib, ... }:
{
  environment.systemPackages = [
    pkgs.sbctl
  ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  boot.lanzaboote.enable = lib.mkDefault true;
  boot.lanzaboote.pkiBundle = lib.mkDefault "/var/lib/sbctl";
}
