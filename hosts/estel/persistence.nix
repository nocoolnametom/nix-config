###############################################################################
#
# System-Level Persistence (User-level is handled in home/<user>/persistence/estel.nix
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
      "/var/lib/acme"
      "/var/lib/audiobookshelf"
      "/var/lib/bluetooth"
      "/var/lib/caddy"
      "/var/lib/docker"
      "/var/lib/hedgedoc"
      "/var/lib/immich"
      "/var/lib/iwd"
      "/var/lib/karakeep"
      "/var/lib/kavita"
      "/var/lib/kavitan"
      "/var/lib/kavitan-library"
      "/var/lib/navidrome"
      "/var/lib/nixos"
      "/var/lib/ombi"
      "/var/lib/paperless"
      "/var/lib/postgresql"
      "/var/lib/private/actual"
      "/var/lib/private/ddclient"
      "/var/lib/private/karakeep-browser"
      "/var/lib/private/mealie"
      "/var/lib/redis-immich"
      "/var/lib/redis-paperless"
      "/var/lib/sbctl"
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
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

  # /var/lib/private handling is now automatic via auto-persist-dirs.nix
}
