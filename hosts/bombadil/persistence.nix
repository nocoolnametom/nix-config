###############################################################################
#
# System-Level Persistence (User-level is handled in home/<user>/persistence/bombadil.nix
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
      "/var/cache/nginx/cache/akkoma-media-cache"
      "/var/db/sudo/lectured"
      "/var/lib/acme"
      "/var/lib/akkoma"
      "/var/lib/chrony"
      "/var/lib/elasticsearch"
      "/var/lib/fail2ban"
      "/var/lib/gotosocial"
      "/var/lib/mastodon"
      "/var/lib/mysql"
      "/var/lib/nixos"
      "/var/lib/pleroma"
      "/var/lib/postfix"
      "/var/lib/postgresql"
      "/var/lib/redis-mastodon"
      "/var/lib/systemd/coredump"
      "/var/lib/private/uptime-kuma"
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

  # Because we're persisting a /var/lib/private directory impermanence will create /var/lib/private for mounting
  #`This is bad, though, because it's made with the wrong permissions for private systemd services to use
  # So we need to change the permissions BACK to what they should be after starting up.
  system.activationScripts."createPersistentStorageDirs".deps = [
    "var-lib-private-permissions"
    "users"
    "groups"
  ];
  system.activationScripts = {
    "var-lib-private-permissions" = {
      deps = [ "specialfs" ];
      text = ''
        mkdir -p /persist/var/lib/private
        chmod 0700 /persist/var/lib/private
      '';
    };
  };
}
