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

  # systemd-pcrlock saves its policy by writing a temp file and renaming it over
  # the old one. A rename onto a bind-mounted *file* fails with EBUSY, so the
  # policy in the TPM moved on while the persisted copy stayed stale, and every
  # later rebuild failed with "None of the alternative values for PCR 4...".
  # Keep the policy inside a persisted *directory* instead, where rename works.
  boot.lanzaboote.measuredBoot.pcrlockPolicy = "/var/lib/pcrlock-policy/pcrlock.json";

  # this folder is where the files will be stored (don't put it in tmpfs)
  environment.persistence."${configVars.persistFolder}" = {
    enable = lib.mkDefault true;
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/sbctl"
      "/var/lib/auto-cryptenroll"
      "/var/lib/pcrlock.d"
      "/var/lib/pcrlock-policy" # pcrlock.json, see measuredBoot.pcrlockPolicy below
      "/var/db/sudo/lectured"
      "/var/lib/beszel-agent" # Beszel agent fingerprint/identity
      "/var/lib/bluetooth"
      "/var/lib/cosmic-greeter" # Remembers last-chosen session/user
      # "/var/lib/cups" # Handling via NixOS options
      "/var/lib/docker"
      "/var/lib/fprint"
      "/var/lib/comin" # comin deployment state + repo checkout
      "/var/lib/nixos"
      "/var/lib/nixpkgs-downgrade-guard" # newest nixpkgs ever activated here
      "/var/lib/systemd/coredump"
    ];
    files = [
      "/etc/machine-id"
      "/etc/machine-info"
      "/etc/nix/id_rsa"
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
}
