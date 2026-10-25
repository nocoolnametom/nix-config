{ pkgs, lib, config, ... }:
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
  boot.lanzaboote.autoEnrollKeys.enable = lib.mkDefault true;
  boot.lanzaboote.autoEnrollKeys.includeMicrosoftKeys = lib.mkDefault true;
  boot.lanzaboote.autoEnrollKeys.allowBrickingMyMachine = lib.mkDefault false;
  boot.lanzaboote.autoEnrollKeys.includeFirmwareBuiltinKeys = lib.mkDefault true;
  boot.lanzaboote.autoEnrollKeys.autoReboot = lib.mkDefault true;
  boot.lanzaboote.measuredBoot.enable = lib.mkDefault true;
  boot.lanzaboote.measuredBoot.pcrs = lib.mkDefault [ 0 1 2 3 4 7 ];
  boot.lanzaboote.configurationLimit = lib.mkDefault (if config.boot.lanzaboote.measuredBoot.enable then 4 else config.boot.loader.systemd-boot.configurationLimit);
}
