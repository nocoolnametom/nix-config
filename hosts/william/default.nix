###############################################################################
#
#  Bert - RasPi
#  NixOS running on Raspberry Pi 4 Model B Rev 1.4
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
    inputs.hardware.nixosModules.raspberry-pi-5

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

    # Actual Budget
    "hosts/common/optional/services/actual-budget.nix"
    # Audiobookshelf
    "hosts/common/optional/services/audiobookshelf.nix"
    # Immich Public Proxy
    "hosts/common/optional/services/immich-public-proxy.nix"
    # Karakeep
    "hosts/common/optional/services/karakeep.nix"
    # Kavita
    "hosts/common/optional/services/kavita.nix"
    # Navidrome
    "hosts/common/optional/services/navidrome.nix"
    # Ombi
    "hosts/common/optional/services/ombi.nix"
    # calibre-web-automated via docker?
    # tube-archivist via docker?

    #################### Users to Create ####################
    "home/${configVars.username}/persistence/william.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # I'm not currently running persistence on the RasPi! RAM is too limited.
  environment.persistence."${configVars.persistFolder}".enable = lib.mkForce false;

  ## Imports overrides

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "william";
    nameservers = [
      "1.1.1.1#one.one.one.one"
      "1.0.0.1#one.one.one.one"
      "8.8.8.8#eight.eight.eight.eight"
    ];
    networkmanager.enable = true;
    enableIPv6 = true;
    # Bert is behind a NAT, so access to ports is already restricted
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

  users.users.root.initialHashedPassword = "$y$j9T$Mm6q6iMh6EExH6KXCxJMo0$i5B3WiTn0iugMb2WcRpCuOw/6QA..GSrTcPZZjMhKy6";
}
