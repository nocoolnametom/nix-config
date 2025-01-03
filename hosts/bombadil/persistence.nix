###############################################################################
#
# System-Level Persistence (User-level is handled in home/<user>/bombadil/persistence.nix
#
###############################################################################

{
  inputs,
  configVars,
  config,
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
      "/var/backup/mysql"
      "/var/backup/postgresql"
      "/var/db/sudo/lectured"
      "/var/lib/acme"
      "/var/lib/chrony"
      "/var/lib/elasticsearch"
      "/var/lib/fail2ban"
      "/var/lib/mastodon"
      "/var/lib/mysql"
      "/var/lib/nixos"
      "/var/lib/postfix"
      "/var/lib/postgresql"
      "/var/lib/redis-mastodon"
      "/var/lib/systemd/coredump"
      "/var/lib/wordpress"
    ];
    files = [
      "/etc/machine-id"
      "/etc/nix/id_rsa"
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
