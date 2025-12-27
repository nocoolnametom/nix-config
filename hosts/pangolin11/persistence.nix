###############################################################################
#
# System-Level Persistence (User-level is handled in home/<user>/persistence/thinkpadx1.nix
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
      "/var/lib/sbctl"
      "/var/db/sudo/lectured"
      "/var/lib/bluetooth"
      # "/var/lib/cups" # Handling via NixOS options
      "/var/lib/docker"
      "/var/lib/fprint"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/log"
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
}
