###############################################################################
#
#  Droid - Pixel 10 Fold AVF
#
###############################################################################

{
  inputs,
  pkgs,
  lib,
  configLib,
  config,
  configVars,
  ...
}:
{
  imports = [
    # Hardware config: replace with a copy of the correct hardware-configuration.nix
    ./hardware-configuration.nix

    # Persistence (adjust as needed)
    ./persistence.nix
  ]
  ++ (map configLib.relativeToRoot [
    "hosts/common/core"

    # GPG Agent with SSH support
    "hosts/common/optional/gpg-agent.nix"

    # Copy the same optional service modules as bert; enable/disable as you prefer
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/direnv.nix"
    "hosts/common/optional/foreign-binaries.nix"

    # Create per-user persistence entry for droid
    "home/${configVars.username}/persistence/droid.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # Networking basics - update IPs and names for droid
  networking = {
    hostName = "droid";
    enableIPv6 = true;
    firewall.allowedTCPPorts = [
      80
      443
      configVars.networking.ports.tcp.remoteSsh
      configVars.networking.ports.tcp.localSsh
    ];
    firewall.allowedUDPPorts = [ 443 ];
    firewall.allowPing = true;
  };

  users.users.${configVars.username}.hashedPassword =
    lib.mkForce "$y$j9T$5SGpsUDjjH9wZ61QMwXf0.$C.cQnNS.mmXLEQ34/cqfpU.LXJ0BydbEFr4oukpn8u/";

  environment.systemPackages = with pkgs; [
    fuse
    glibcLocales
    nodejs
    p7zip
    yt-dlp
    samba
    screen
    unrar
    unzip
    vim
    wget
    chromium
  ];

  services.fail2ban.enable = false;

  system.stateVersion = "25.11";
}
