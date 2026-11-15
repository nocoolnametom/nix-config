###############################################################################
#
# System-Level Persistence (User-level is handled in home/<user>/persistence/barliman.nix
#
###############################################################################

{
  inputs,
  configVars,
  configLib,
  lib,
  ...
}:

{
  imports = [
    inputs.impermanence.nixosModules.impermanence
    (configLib.relativeToRoot "hosts/common/optional/auto-persist-dirs.nix")
  ];

  # this folder is where the files will be stored (don't put it in tmpfs)
  environment.persistence."${configVars.persistFolder}" = {
    enable = lib.mkDefault true;
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/db/sudo/lectured"
      # agent-worker's clones and its own SSH keys (hosts/common/optional/services/agent-worker.nix)
      {
        directory = "/var/lib/agent-worker";
        user = "agent-worker";
        group = "agent-worker";
        mode = "0700";
      }
      "/var/lib/bluetooth"
      "/var/lib/chrony"
      "/var/lib/comin" # comin deployment state + repo checkout
      # "/var/lib/cups" # Handling via NixOS options
      "/var/lib/docker"
      "/var/lib/fwupd" # LVFS firmware client: pending.db holds queued updates applied at reboot
      "/var/lib/hermes"
      "/var/lib/nixos"
      "/var/lib/nixpkgs-downgrade-guard" # newest nixpkgs ever activated here
      "/var/lib/ollama"
      {
        directory = "/var/lib/private/open-webui";
        mode = "0700";
      }
      "/var/lib/strata"
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
      # "/var/lib/cups/printers.conf" # Handling via NixOS options
      # logrotate.status is NOT bind-mounted: logrotate writes via atomic rename
      # (write temp, rename into place) which fails on a bind-mount target with
      # "Device or resource busy". Losing it on reboot is harmless: logrotate
      # recreates it and may re-rotate a few logs once. (Same fix as feanor.)
      # "/var/lib/logrotate.status"
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

  # DISABLED for now: this rollback deletes the root subvolume on every boot and
  # restores root-blank, which is currently empty (an empty root would not boot).
  # Re-enable only after root-blank is a verified blank template, and only with the
  # systemd-initrd rollback-root pattern from hosts/bombadil/hardware-configuration.nix
  # (postResumeCommands is rejected under systemd initrd).
  /* boot.initrd.postResumeCommands = lib.mkAfter ''
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
  ''; */
}
