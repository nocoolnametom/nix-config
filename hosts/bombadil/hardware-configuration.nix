# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{
  config,
  lib,
  modulesPath,
  ...
}:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [
    "ahci"
    "sd_mod"
    "virtio_pci"
    "virtio_scsi"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [
      "defaults"
      "compress=zstd"
      "noatime"
      "subvol=root"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [
      "defaults"
      "compress=zstd"
      "noatime"
      "subvol=boot"
    ];
    neededForBoot = true;
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [
      "defaults"
      "compress=zstd"
      "noatime"
      "subvol=home"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [
      "defaults"
      "compress=zstd"
      "noatime"
      "subvol=nix"
    ];
    neededForBoot = true;
  };

  fileSystems."/etc/nixos" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [
      "defaults"
      "compress=zstd"
      "noatime"
      "subvol=nixos-config"
    ];
  };

  fileSystems."/persist" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [
      "defaults"
      "compress=zstd"
      "noatime"
      "subvol=persist"
    ];
    neededForBoot = true;
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [
      "defaults"
      "compress=zstd"
      "noatime"
      "subvol=log"
    ];
    neededForBoot = true;
  };

  # Swap
  swapDevices = [
    { device = "/dev/disk/by-label/swap"; }
    {
      device = "/var/lib/swapfile";
      size = 3 * 1024;
    }
  ];

  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s5.useDHCP = lib.mkDefault true;

  boot.initrd.enable = true;
  boot.supportedFilesystems = [ "btrfs" ];
  boot.initrd.postResumeCommands = lib.mkAfter ''
    mkdir -p /mnt
    # We first mount the btrfs root to /mnt
    # so we can manipulate btrfs subvolumes.
    mount -o subvol=/ /dev/disk/by-label/nixos /mnt

    # While we're tempted to just delte /root and create
    # a new snapshot from /root-black, /root is already
    # populated at this point with a number of subvolumes,
    # which makes `btrfs subvolume delete` fail.
    # So, we remove them first.
    # 
    # /root contains subvolumes:
    # - /root/var/lib/portables
    # - /root/var/lib/machines
    # 
    # I suspecte these are related to systemd-nspawn, but
    # since I don't use it I'm not 100% sure.
    # Anyhow, deleting these subvolumes hasn't resulted
    # in any issues so far, except for fairly
    # benign-looking error from systemd-tmpfiles.
    btrfs subvolume list -o /mnt/root |
    cut -f9 -d ' ' |
    while read subvolume; do
      echo "deleting /$subvolume subvolume..."
      btrfs subvolume delete "/mnt/$subvolume"
    done &&
    echo "deleting /root subvolume..." &&
    btrfs subvolume delete /mnt/root

    echo "restoring blank /root subvolume..."
    btrfs subvolume snapshot /mnt/root-blank /mnt/root

    # Once we're done rolling back to a blank snapshot,
    # we can unmount /mnt and continue on the boot process.
    umount /mnt
  '';

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
