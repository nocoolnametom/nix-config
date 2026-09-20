###############################################################################
#
#  Feanor - Hardware Configuration (UGREEN DXP4800 Plus)
#
#  !!! PLACEHOLDER !!!
#  Written before the hardware arrived so the flake evaluates. Replace the
#  kernel-module lists with the output of `nixos-generate-config` on the real
#  box, then keep the filesystem layout below (it is the intended design, not
#  a guess at what the installer will produce).
#
#  ---------------------------------------------------------------------------
#  Disk layout
#  ---------------------------------------------------------------------------
#  Factory UGOS SSD (internal NVMe slot)  - LEFT ALONE except for its ESP.
#      The DXP4800 Plus only boots from this slot, so the NixOS bootloader is
#      installed into the vendor ESP alongside UGOS's. Keeping the rest of the
#      disk untouched means a BIOS boot-order change restores the stock NAS.
#
#  User M.2 #1  -> label `formenos`  (btrfs, OS)
#      subvol /root        -> /
#      subvol /root-blank  -> pristine snapshot, restored every boot
#      subvol /nix         -> /nix
#      subvol /persist     -> /persist   (impermanence target)
#      subvol /log         -> /var/log
#
#  User M.2 #2  -> unused for now. Candidate: bcache/L2ARC-equivalent, or a
#      second copy of /persist. Deliberately left out of the pool so a failure
#      can't take data with it.
#
#  SATA bays -> label `silmaril`  (btrfs RAID1 data + metadata)
#      Mounted at /silmaril. Drive inventory is 2x20TB + 2x26TB, built up in
#      two phases while cirdan still holds the live data.
#
#      btrfs RAID1 usable space with mixed drives is min(sum/2, sum - largest),
#      so unlike ZFS mirrors (which cap each vdev at its smallest member and
#      would strand 12 TB here) every byte of raw capacity gets used:
#
#        phase 1, 3 drives (20+20+26):  min(33, 40) = 33 TB usable
#        phase 2, 4 drives (+26):       min(46, 66) = 46 TB usable
#
#  Phase 1 - create the pool (adjust device paths!):
#      mkfs.btrfs -L silmaril -d raid1 -m raid1 /dev/sdX /dev/sdY /dev/sdZ
#
#  Phase 2 - fold in cirdan's last drive once the copy is verified:
#      btrfs device add /dev/sdW /silmaril
#      btrfs balance start /silmaril      # days at this size; safe to resume
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
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.supportedFilesystems = [ "btrfs" ];

  # Boot from the factory UGOS SSD's ESP - see the header comment. No
  # Lanzaboote here: sharing an ESP with the vendor bootloader and then
  # enrolling Secure Boot keys with sbctl is how you end up with a brick.
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

  # TODO: confirm the vendor ESP's label/UUID on the real hardware.
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
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
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
}
