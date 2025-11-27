###############################################################################
# Persistence for durin (adapted from bert)
# Edit mounts and directories to match durin's disks and needs.
###############################################################################

{
  inputs,
  configVars,
  lib,
  ...
}:

{
  imports = [ inputs.impermanence.nixosModules.impermanence ];

  environment.persistence."${configVars.persistFolder}" = {
    enable = lib.mkDefault false;
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/db/sudo/lectured"
      "/var/lib/bluetooth"
      "/var/lib/docker"
      "/var/lib/fprint"
      "/var/lib/netbox"
      "/var/lib/nixos"
      "/var/lib/postgresql"
      "/var/lib/redis"
      "/var/lib/systemd/coredump"
      "/var/log"
    ];
    files = [
      "/etc/machine-id"
      "/etc/nix/id_rsa"
      "/var/lib/logrotate.status"
      {
        file = "/etc/ssh/ssh_host_ed25519_key";
        parentDirectory = { mode = "0755"; };
      }
      {
        file = "/etc/ssh/ssh_host_ed25519_key.pub";
        parentDirectory = { mode = "0755"; };
      }
      {
        file = "/etc/ssh/ssh_host_rsa_key";
        parentDirectory = { mode = "0755"; };
      }
      {
        file = "/etc/ssh/ssh_host_rsa_key.pub";
        parentDirectory = { mode = "0755"; };
      }
    ];
  };
}
