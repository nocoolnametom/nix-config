###############################################################################
#
# System-Level Persistence (User-level is handled in home/<user>/persistence/estel.nix
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
    enable = lib.mkDefault false;
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/sbctl"
      "/var/db/sudo/lectured"
      "/var/lib/bluetooth"
      # "/var/lib/cups" # Handling via NixOS options
      #"/var/lib/docker"
      #"/var/lib/fprint"
      #"/var/lib/netbox"
      "/var/lib/nixos"
      #"/var/lib/postgresql"
      #"/var/lib/redis"
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
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
