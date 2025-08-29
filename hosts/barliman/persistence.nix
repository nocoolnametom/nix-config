###############################################################################
#
# System-Level Persistence (User-level is handled in home/<user>/persistence/barliman.nix
#
###############################################################################

{
  inputs,
  configVars,
  lib,
  ...
}:

{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  # this folder is where the files will be stored (don't put it in tmpfs)
  environment.persistence."${configVars.persistFolder}" = {
    enable = lib.mkDefault true;
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/db/sudo/lectured"
      "/var/lib/bluetooth"
      "/var/lib/chrony"
      # "/var/lib/cups" # Handling via NixOS options
      "/var/lib/docker"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
      "/etc/machine-info"
      "/etc/nix/id_rsa"
      # "/var/lib/cups/printers.conf" # Handling via NixOS options
      "/var/lib/logrotate.status"
      {
        file = "/etc/ssh/ssh_host_ed25519_key";
        parentDirectory = {
          mode = "0755";
        };
      }
      {
        file = "/etc/ssh/ssh_host_ed25519_key.pub";
        parentDirectory = {
          mode = "0755";
        };
      }
      {
        file = "/etc/ssh/ssh_host_rsa_key";
        parentDirectory = {
          mode = "0755";
        };
      }
      {
        file = "/etc/ssh/ssh_host_rsa_key.pub";
        parentDirectory = {
          mode = "0755";
        };
      }
    ];
  };

  # Uses a blank snapshot to replace root so that all memory
  # can be used as memory!
  boot.initrd.postResumeCommands = lib.mkAfter ''
    mkdir -p /mnt
    # We first mount the btrfs root to /mnt
    # so we can manipulate btrfs subvolumes.
    mount -o subvol=/ /dev/disk/by-label/prancing /mnt

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
}
