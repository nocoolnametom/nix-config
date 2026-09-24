###############################################################################
#
# System-Level Persistence
# (User-level lives in home/<user>/persistence/feanor.nix)
#
# Root is wiped on every boot from the `root-blank` snapshot; only what is
# listed here survives. Adapted from hosts/barliman/persistence.nix, with the
# btrfs label changed to `formenos`.
#
# NOTE ON THE DOCKER PHASE:
# While stacks are still being hand-tuned through Komodo, every new bind-mount
# path a container wants must be added below (or live under /silmaril, which
# is a separate pool and is never wiped). A container that writes to an
# undeclared path on the root filesystem will silently lose its data at the
# next reboot. `enable` is lib.mkDefault so you can flip it off for a boot if
# something needs chasing down.
#
###############################################################################

{
  inputs,
  config,
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

  environment.persistence."${configVars.persistFolder}" = {
    enable = lib.mkDefault true;
    hideMounts = true;
    directories = [
      "/var/db/sudo/lectured"
      "/var/lib/beszel-agent" # Beszel agent fingerprint/identity
      "/var/lib/chrony"
      "/var/lib/docker" # container images + volumes
      "/var/lib/jellyfin" # library DB, metadata, user state
      # "/var/lib/immich"  # re-enable when Immich goes native (see default.nix)
      "/var/lib/nixos"
      "/var/lib/postgresql" # immich DB - on NVMe, not the btrfs HDD pool
      "/var/lib/private/webdav"
      "/var/lib/samba"
      "/var/lib/syncthing" # index DB + device keys; losing this re-hashes everything
      "/var/lib/systemd/coredump"
      "/var/lib/tailscale"

      # Komodo keeps each stack as a plain compose.yaml on disk. Persisting
      # this directory is what makes the eventual arion migration a matter of
      # reading files rather than exporting from a database.
      "/var/lib/komodo"
    ];
    files = [
      "/etc/machine-id"
      "/etc/machine-info"
      "/etc/nix/id_rsa"
      # logrotate.status is NOT bind-mounted: logrotate writes via atomic rename
      # (write temp, rename into place) which fails on a bind-mount target with
      # "Device or resource busy".  Losing it on reboot is harmless — logrotate
      # recreates it and may re-rotate a few logs once.
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

  # Restore the blank root subvolume on every boot, so that anything not
  # persisted above is genuinely gone.
  #
  # This follows hosts/bombadil/hardware-configuration.nix, NOT the older
  # boot.initrd.postResumeCommands form in hosts/barliman/persistence.nix -
  # that option is rejected outright under systemd stage 1 initrd, which every
  # host in this repo now uses. (barliman only gets away with it because its
  # persistence.nix import is commented out.)
  #
  # /root already contains nested subvolumes by this point (var/lib/machines,
  # var/lib/portables), and `btrfs subvolume delete` refuses to remove a
  # subvolume that still has children - hence the delete loop before the
  # snapshot restore.
  boot.initrd.systemd.services.rollback-root = {
    description = "Rollback root filesystem to blank snapshot";
    wantedBy = [ "initrd.target" ];
    after = [ "initrd-root-device.target" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /mnt
      mount -o subvol=/ /dev/disk/by-label/formenos /mnt

      btrfs subvolume list -o /mnt/root |
      cut -f9 -d ' ' |
      while read subvolume; do
        echo "deleting /$subvolume subvolume..."
        btrfs subvolume delete "/mnt/$subvolume"
      done

      echo "deleting /root subvolume..."
      btrfs subvolume delete /mnt/root

      echo "restoring blank /root subvolume..."
      btrfs subvolume snapshot /mnt/root-blank /mnt/root

      umount /mnt
    '';
  };
}
