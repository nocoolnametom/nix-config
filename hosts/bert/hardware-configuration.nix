# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  config,
  configVars,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "ahci"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };
  fileSystems."/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
  };
  fileSystems."/media/g_drive" = {
    device = "/dev/disk/by-label/g_drive";
    fsType = "ext4";
    options = [
      "auto"
      "noatime"
      "commit=60"
      "discard"
      "errors=remount-ro"
    ];
  };
  fileSystems."/mnt/bigssd" = {
    device = "/dev/disk/by-label/bigssd";
    fsType = "ext4";
    options = [
      "auto"
      "errors=remount-ro"
    ];
  };
  fileSystems."/mnt/Backup" = {
    device = "/dev/disk/by-label/DoggettBackup";
    fsType = "ext4";
    options = [
      "auto"
      "errors=remount-ro"
    ];
  };

  # Cirdan SMB mounts
  fileSystems."/mnt/cirdan/smb/Movies" = cirdanSmbConfig "Movies";
  fileSystems."/mnt/cirdan/smb/TV_Shows" = cirdanSmbConfig "TV_Shows";
  fileSystems."/mnt/cirdan/smb/data.dat" = cirdanSmbConfig "data.dat";
  fileSystems."/mnt/cirdan/smb/NetBackup" = cirdanSmbConfig "NetBackup";
  fileSystems."/mnt/cirdan/smb/Family_Data" = cirdanSmbConfig "Family_Data";

  # Swap
  swapDevices = [
    {
      device = "/swapfile";
      size = 1024;
    }
  ];

  powerManagement.cpuFreqGovernor = "ondemand";

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlan0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
