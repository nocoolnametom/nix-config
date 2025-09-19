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
    enable = lib.mkDefault true;
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/db/sudo/lectured"
      "/var/lib/acme"
      "/var/lib/audiobookshelf"
      "/var/lib/bluetooth"
      "/var/lib/caddy"
      "/var/lib/docker"
      "/var/lib/fprint"
      "/var/lib/hedgedoc"
      #"/var/lib/immich"
      "/var/lib/iwd"
      "/var/lib/karakeep"
      "/var/lib/kavita"
      "/var/lib/kavitan"
      "/var/lib/navidrome"
      "/var/lib/nixos"
      "/var/lib/ombi"
      #"/var/lib/paperless"
      "/var/lib/postresql"
      "/var/lib/private/actual"
      "/var/lib/private/ddclient"
      "/var/lib/private/mealie"
      "/var/lib/redis-immich"
      #"/var/lib/redis-paperless"
      "/var/lib/sbctl"
      "/var/lib/systemd/coredump"
      "/var/lib/tor"
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

  system.activationScripts."createPersistentStorageDirs".deps = [ "var-lib-private-permissions" "users" "groups" ];
  system.activationScripts = {
    "var-lib-private-permissions" = {
      deps = [ "specialfs" ];
      text = ''
        mkdir -p /persist/var/lib/private
        chmod 0700 /persist/var/lib/private
      '';
    };
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/private 0700 root root"
  ];
}
