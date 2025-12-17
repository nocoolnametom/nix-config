###############################################################################
#
# System-Level Persistence (User-level is handled in home/<user>/persistence/durin.nix
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
      "/var/lib/bluetooth"
      "/var/lib/chrony"
      # "/var/lib/cups" # Handling via NixOS options
      "/var/lib/deluge/.config/deluge"
      "/var/lib/docker"
      "/var/lib/nixos"
      "/var/lib/nzbget/queue"
      "/var/lib/nzbget/scripts"
      "/var/lib/nzbhydra2"
      "/var/lib/pinchflat/db"
      "/var/lib/pinchflat/extras"
      "/var/lib/private/flood"
      "/var/lib/radarr/.config/Radarr"
      "/var/lib/sbctl"
      "/var/lib/sickgear"
      "/var/lib/sonarr/.config/NzbDrone"
      "/var/lib/stashapp/.config/chromium"
      "/var/lib/stashapp/.stash"
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
      "/etc/machine-info"
      "/etc/nix/id_rsa"
      # "/var/lib/cups/printers.conf" # Handling via NixOS options
      "/var/lib/logrotate.status"
      "/var/lib/nzbget/nzbget.conf"
      "/var/lib/stashapp/.stash/config.yml"
      "/var/lib/systemd/tpm2-srk-public-key.pem"
      "/var/lib/systemd/tpm2-srk-public-key.tpm2b_public"
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

  # Only create/modify activation scripts if persistence is enabled
  system.activationScripts = lib.mkIf (
    config.environment.persistence."${configVars.persistFolder}".enable
  ) {
    # Create our custom script to set up /var/lib/private
    "var-lib-private-permissions" = {
      deps = [ "specialfs" ];
      text = ''
        mkdir -p ${configVars.persistFolder}/var/lib/private
        chmod 0700 ${configVars.persistFolder}/var/lib/private
      '';
    };

    # Extend the impermanence createPersistentStorageDirs script to depend on our script
    "createPersistentStorageDirs" = {
      deps = [
        "var-lib-private-permissions"
        "users"
        "groups"
      ];
    };
  };

  # Always ensure /var/lib/private has correct permissions (even without persistence)
  systemd.tmpfiles.rules = [
    "d /var/lib/private 0700 root root"
  ];
}
