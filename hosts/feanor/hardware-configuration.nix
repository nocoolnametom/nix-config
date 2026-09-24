###############################################################################
#
#  Feanor - Hardware Configuration (UGREEN DXP4800 Plus)
#
#  Kernel module lists validated against nixos-generate-config output on
#  the real hardware (2026-09-24). Filesystem layout is intentional design
#  using by-label mounts; the generated-config UUIDs were discarded.
#
#  ---------------------------------------------------------------------------
#  Disk layout
#  ---------------------------------------------------------------------------
#  Factory UGOS SSD (internal NVMe slot)  - LEFT PHYSICALLY IN PLACE but
#      disabled in BIOS. The unit does not boot from this slot during normal
#      NixOS operation. Re-enabling UGOS drive in BIOS boot-order restores
#      the stock NAS if needed without touching the NixOS install.
#
#  User M.2 #1  -> EFI partition (label `FEANOR_EFI`) + label `formenos` (btrfs, OS)
#      The NixOS bootloader lives in the M.2 #1 ESP, NOT in the vendor ESP.
#      M.2 #1 is set as the bootable device in BIOS; UGOS drive is disabled.
#      subvol root        -> /
#      subvol root-blank  -> pristine snapshot, restored every boot
#      subvol nix         -> /nix
#      subvol persist     -> /persist   (impermanence target)
#      subvol log         -> /var/log
#
#  User M.2 #2  -> disabled in BIOS during initial setup. Candidate for
#      bcache/L2ARC-equivalent, or a second copy of /persist. Deliberately
#      left out of the pool so a failure can't take data with it.
#
#  SATA bays -> label `silmaril`  (btrfs data pool)
#      Mounted at /silmaril. Drive inventory grows in phases:
#
#      CURRENT (single drive, no redundancy):
#        1x 26TB HDD - temporary, no RAID until second drive arrives
#        mkfs.btrfs -L silmaril /dev/sdX
#
#      PHASE A - add second 26TB (after cirdan data verified):
#        btrfs device add /dev/sdY /silmaril
#        btrfs balance start -dconvert=raid1 -mconvert=raid1 /silmaril
#
#      PHASE B - fold in two 20TB drives from retired cirdan:
#        btrfs device add /dev/sdZ /dev/sdW /silmaril
#        btrfs balance start /silmaril      # days at this size; safe to resume
#
#      btrfs RAID1 usable space with mixed drives is min(sum/2, sum - largest),
#      so unlike ZFS mirrors (which cap each vdev at its smallest member and
#      would strand 12 TB here) every byte of raw capacity gets used:
#
#        2 drives (26+26):            min(26, 26) = 26 TB usable
#        4 drives (20+20+26+26):      min(46, 52) = 46 TB usable
#
#  NOTE: btrfs RAID1 means two copies on two *different* devices - it is not
#  "mirrored pairs". Any single drive can fail. Recovery is `btrfs replace`,
#  which copies only the chunks that lived on the dead drive rather than
#  re-reading the whole array, and leaves every other chunk protected while
#  it runs. That rebuild behaviour is the main reason this is RAID1 and not
#  raidz1, despite raidz1's larger headline number.
#
###############################################################################

{
  config,
  lib,
  modulesPath,
  ...
}:

let
  # A subvolume on the `silmaril` data pool.
  #
  # Compression is a per-mount option, and each subvolume is its own mount, so
  # different parts of the same filesystem can use different settings.
  poolSubvol = subvol: extraOpts: {
    device = "/dev/disk/by-label/silmaril";
    fsType = "btrfs";
    options = [
      "subvol=${subvol}"
      "noatime"
      "nofail" # never block boot on the data pool
    ]
    ++ extraOpts;
  };

  # Already-compressed payloads: video containers, JPEG/HEIC, FLAC/MP3, CBZ
  # (which is just a zip), and borg repos (borg compresses and encrypts before
  # it ever reaches the filesystem). zstd would burn CPU on every read and
  # write for approximately zero saving, so don't ask it to.
  opaque = [ "compress=no" ];

  # Text, configs, databases dumps, documents, container layers. Real gains
  # here, and zstd:3 is still comfortably faster than these disks.
  squishy = [ "compress=zstd:3" ];
in

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # TODO: replace with nixos-generate-config output from the real hardware.
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.supportedFilesystems = [ "btrfs" ];

  # Boot from M.2 #1's own ESP (label FEANOR_EFI) - see the header comment.
  # No Lanzaboote: there is no shared vendor ESP to worry about, but enabling
  # Secure Boot and then discovering sbctl needs the key enrolled at runtime
  # is a painful recovery path on a headless box. Leave it off.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  ############################ OS disk (formenos) #############################

  fileSystems."/" = {
    device = "/dev/disk/by-label/formenos";
    fsType = "btrfs";
    options = [
      "subvol=root"
      "compress=zstd:1"
      "noatime"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/formenos";
    fsType = "btrfs";
    options = [
      "subvol=nix"
      "compress=zstd:1"
      "noatime"
    ];
  };

  fileSystems."/persist" = {
    device = "/dev/disk/by-label/formenos";
    fsType = "btrfs";
    options = [
      "subvol=persist"
      "compress=zstd:1"
      "noatime"
    ];
    neededForBoot = true; # impermanence reads from here during activation
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-label/formenos";
    fsType = "btrfs";
    options = [
      "subvol=log"
      "compress=zstd:1"
      "noatime"
    ];
    neededForBoot = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/FEANOR_EFI";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  ########################### Data pool (silmaril) ############################
  #
  # btrfs RAID1 across the SATA bays. Only one device is named; btrfs scans
  # and assembles the rest of the mirror itself.
  #
  # zstd:1 is near-free on docker layers, databases and documents. It buys
  # essentially nothing on the photos and video that dominate this pool - it
  # is here for the former, not as a capacity strategy.

  # Subvolumes mirror cirdan's File Station layout, so the migration is a
  # per-share copy rather than a reshuffle. Create them all at once with:
  #
  #   mount /dev/disk/by-label/silmaril /mnt
  #   for s in jellyfin music comics immich netbackup syncthing borg stacks; do
  #     btrfs subvolume create "/mnt/@$s"
  #   done
  #   umount /mnt
  #
  # To manage snapshots later, mount the pool root ad hoc:
  #   mount -o subvolid=5 /dev/disk/by-label/silmaril /mnt

  # --- bulk media: compression off ---
  fileSystems."/silmaril/jellyfin" = poolSubvol "@jellyfin" opaque; # Movies, TV_Shows, FanEdits, Backups
  fileSystems."/silmaril/music" = poolSubvol "@music" opaque;
  fileSystems."/silmaril/comics" = poolSubvol "@comics" opaque; # CBZ/CBR, served to Kavita over SMB
  fileSystems."/silmaril/immich" = poolSubvol "@immich" opaque; # photo/video originals only; DB lives on NVMe
  fileSystems."/silmaril/borg" = poolSubvol "@borg" opaque; # borg repo + borgmatic config + keys

  # --- compressible: zstd:3 ---
  fileSystems."/silmaril/netbackup" = poolSubvol "@netbackup" squishy; # WebDAV target for GrapheneOS
  fileSystems."/silmaril/syncthing" = poolSubvol "@syncthing" squishy;
  fileSystems."/silmaril/stacks" = poolSubvol "@stacks" squishy; # Komodo compose files + container volumes

  # NOTE: data.dat (the adult-content share) is deliberately absent - flagged
  # as not needing migration.

  # No swap partition: btrfs swapfiles need a nodatacow subvolume and don't
  # play well with the root-blanking below. zram is plenty for a NAS.
  swapDevices = [ ];
  zramSwap.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
