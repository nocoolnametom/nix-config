###############################################################################
#
# System-Level Persistence (User-level is handled in home/tdoggett/thinkpadx1/persistence.nix
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
      "/var/db/sudo/lectured"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/log"
      "/var/lib/postgresql"
      "/var/lib/elasticsearch"
      "/var/lib/mastodon"
      "/var/lib/postfix"
      "/var/lib/redis-mastodon"
    ];
    files = [
      "/etc/machine-id"
      "/etc/nix/id_rsa"
      "/var/lib/logrotate.status"
      "/var/lib/fail2ban/fail2ban.sqlite3"
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
