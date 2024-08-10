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

  boot.initrd.luks.devices."root".device = "/dev/disk/by-partuuid/b8f8075a-c68e-4a42-a0aa-44357308117d";

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/boot" = {
    device = "/dev/disk/by-partuuid/65ce1a7e-f179-4d04-b1e4-0069543f9372";
    fsType = "vfat";
  };

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "mode=755"
      "uid=0"
      "gid=0"
    ];
    neededForBoot = true; # required
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/root";
    fsType = "btrfs";
    options = [
      "defaults"
      "compress-force=zstd"
      "noatime"
      "ssd"
      "subvol=nix"
    ];
    neededForBoot = true; # required
  };

  fileSystems."${configVars.persistFolder}" = {
    device = "/dev/mapper/root";
    fsType = "btrfs";
    options = [
      "defaults"
      "compress-force=zstd"
      "noatime"
      "ssd"
      "subvol=persist"
    ];
    neededForBoot = true; # required
  };

  # Not mounting Home so that we use the persist and impermanence instead for home!
  # fileSystems."/home" =
  #   { device = "/dev/mapper/root";
  #     fsType = "btrfs";
  #     options = [ "defaults" "compress-force=zstd" "noatime" "ssd" "subvol=home" ];
  #   };

  fileSystems."/etc/nixos" = {
    device = "/dev/mapper/root";
    fsType = "btrfs";
    options = [
      "defaults"
      "compress-force=zstd"
      "noatime"
      "ssd"
      "subvol=nixos-config"
    ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/ddaa188d-4327-4648-8f99-3107ab10d351";
      randomEncryption.enable = true;
    }
  ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s31f6.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
