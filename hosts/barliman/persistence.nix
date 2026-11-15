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

  # Impermanence rollback: every boot deletes the root subvolume and restores it
  # from root-blank (an empty, read-only template; see the notes in the repo).
  # Uses the systemd-initrd pattern from hosts/bombadil/hardware-configuration.nix.
  # postResumeCommands is rejected under systemd initrd, so it is not used here.
  # Safety net: root-pre-impermanence (read-only copy of root taken before this
  # was enabled) lives at the top level of the prancing pool; delete it once this
  # boot is verified.
  boot.initrd.systemd.services.rollback-root = {
    description = "Rollback root filesystem to blank snapshot";
    wantedBy = [ "initrd.target" ];
    after = [ "initrd-root-device.target" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /mnt
      mount -o subvol=/ /dev/disk/by-label/prancing /mnt

      # Nested subvolumes under /root (systemd-nspawn leftovers, tmp, srv) must go first.
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
