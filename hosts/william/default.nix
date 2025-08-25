###############################################################################
#
#  William - RasPi 5
#  NixOS running on Raspberry Pi 5 Model B
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
    ######################## Every Host Needs This ############################
    ./hardware-configuration.nix

    ########################## Hardware Modules ###############################
    # inputs.hardware.nixosModules.raspberry-pi-5
    inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.base
    # inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.display-vc4
    # inputs.nixos-raspberrypi.nixosModules.raspberry-pi-5.bluetooth

    ############################## Nginx ######################################
    ./caddy.nix

    ########################### Impermanence ##################################
    ./persistence.nix

    ############################## Stylix #####################################
    # inputs.stylix.nixosModules.stylix # No GUI on the RasPi
  ]
  ++ (map configLib.relativeToRoot [
    #################### Required Configs ####################
    "hosts/common/core"

    #################### Host-specific Optional Configs ####################
    "hosts/common/optional/services/ddclient.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/actual-budget.nix"
    "hosts/common/optional/services/audiobookshelf.nix"
    "hosts/common/optional/services/hedgedoc.nix"
    "hosts/common/optional/services/immich-public-proxy.nix"
    "hosts/common/optional/services/karakeep.nix"
    "hosts/common/optional/services/kavita.nix"
    "hosts/common/optional/services/mealie.nix"
    "hosts/common/optional/services/navidrome.nix"
    "hosts/common/optional/services/ombi.nix"
    "hosts/common/optional/services/paperless.nix"
    # tube-archivist via docker?

    #################### Users to Create ####################
    "home/${configVars.username}/persistence/william.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # I'm not currently running persistence on William! RAM is too limited.
  environment.persistence."${configVars.persistFolder}".enable = lib.mkForce false;

  ## Imports overrides
  services.openssh.settings.PermitRootLogin = lib.mkForce "yes";

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "william";
    nameservers = [
      "1.1.1.1#one.one.one.one"
      "1.0.0.1#one.one.one.one"
      "8.8.8.8#eight.eight.eight.eight"
    ];
    wireless.enable = false;
    networkmanager.enable = true;
    networkmanager.wifi.backend = "iwd";
    enableIPv6 = true;
    # William is behind a NAT, so access to ports is already restricted
    firewall.enable = false;
    firewall.allowedTCPPorts = [
      80 # HTTP
      443 # HTTPS
      configVars.networking.ports.tcp.remoteSsh
      configVars.networking.ports.tcp.localSsh
    ];
    firewall.allowedUDPPorts = [
      443 # HTTPS
    ];
    firewall.allowPing = true; # Linode's LISH console requires ping
  };

  services.resolved = {
    enable = true;
    dnssec = "true";
    domains = [ "~." ];
    fallbackDns = [
      "1.1.1.1#one.one.one.one"
      "1.0.0.1#one.one.one.one"
      "8.8.8.8#eight.eight.eight.eight"
    ];
    dnsovertls = "true";
  };

  environment.systemPackages = with pkgs; [
    fuse
    glibcLocales
    gnumake
    samba
    screen
    unrar
    unzip
    vim
    wget
    git
    curl
    tree
    htop
    libraspberrypi
    raspberrypi-eeprom
  ];

  # Use the systemd-boot EFI boot loader.
  boot.tmp.cleanOnBoot = true;
  boot.tmp.useTmpfs = true;
  boot.initrd.systemd.enable = true;

  # Security
  security.sudo.wheelNeedsPassword = false;
  security.apparmor.enable = true;
  # fail2ban wants the firewall enabled first
  services.fail2ban.enable = false;

  # Fixes VSCode remote
  programs.nix-ld.enable = true;

  # Build documentation
  documentation.nixos.enable = false;

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$5SGpsUDjjH9wZ61QMwXf0.$C.cQnNS.mmXLEQ34/cqfpU.LXJ0BydbEFr4oukpn8u/";
}
