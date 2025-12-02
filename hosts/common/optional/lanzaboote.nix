{ pkgs, lib, ... }:
{
  environment.systemPackages = [
    pkgs.sbctl
    pkgs.tpm2-tss
  ];

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  boot.lanzaboote.enable = lib.mkDefault true;
  boot.lanzaboote.pkiBundle = lib.mkDefault "/var/lib/sbctl";
}
