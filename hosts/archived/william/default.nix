###############################################################################
#
#  William - RasPi 5 (ARCHIVED)
#  NixOS running on Raspberry Pi 5 Model B
#
#  This configuration is archived and no longer in active use.
#  It is maintained for reference purposes only.
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
    "hosts/common/optional/services/docker.nix"
    "hosts/common/optional/services/hedgedoc.nix"
    "hosts/common/optional/services/immich.nix"
    "hosts/common/optional/services/immich-public-proxy.nix"
    "hosts/common/optional/services/karakeep.nix"
    "hosts/common/optional/services/kavita.nix" # Turn on and turn off portainers when 0.8.8 is released!
    "hosts/common/optional/services/mealie.nix"
    "hosts/common/optional/services/navidrome.nix"
    "hosts/common/optional/services/ombi.nix"
    "hosts/common/optional/services/paperless.nix"
    # tube-archivist via docker?

    #################### Users to Create ####################
    "home/${configVars.username}/archived/william/persistence.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # Override the default home-manager config loading for archived machines
  home-manager.users.${configVars.username} = lib.mkForce (
    import (configLib.relativeToRoot "home/${configVars.username}/archived/william/default.nix")
  );

  # Mark this system as deprecated
  system.deprecation = {
    isDeprecated = true;
    reason = "Replaced by estel (Beelink SER5 Mini PC)";
    deprecatedSince = "2024-10";
    lastKnownGoodBuild = "c3cb053";
    replacedBy = "estel";
  };

  # I'm not currently running persistence on William! RAM is too limited.
  environment.persistence."${configVars.persistFolder}".enable = lib.mkForce false;

  ## Imports overrides
  services.audiobookshelf.package = lib.mkForce pkgs.unstable.audiobookshelf;
  services.actual.package = lib.mkForce pkgs.unstable.actual-server;
  services.karakeep.enable = lib.mkForce false; # It's not building right now for some reason
  services.karakeep.package = lib.mkForce pkgs.unstable.karakeep;
  services.karakeep.browser.exe = lib.mkForce "${pkgs.unstable.chromium}/bin/chromium";
  services.paperless.enable = lib.mkForce false; # The executable is broken for some reason
  services.paperless.configureTika = lib.mkForce false; # This requires building libreoffice and that isn't building
  services.immich.enable = lib.mkForce false; # Currently tries to inject invalid vector plugins to postgresql which then fails to start
  services.immich.package = lib.mkForce pkgs.unstable.immich;
  services.immich.mediaLocation = "/mnt/cirdan/smb/Immich/uploads/";
  # services.immich.database.enableVectors = lib.mkForce false; # This option should prevent the vector plugins but isn't available on 25.05

  # Currently-Docker Stuff
  # Can replase kavita users below with kavita module when 0.8.8 is released!
  services.kavita.enable = lib.mkForce false; # Using docker right now
  services.kavitan.enable = lib.mkForce false; # Using docker right now
  users.groups.kavita = { };
  users.users.kavita.isSystemUser = true;
  users.users.kavita.group = "kavita";
  users.users.kavita.home = "/var/lib/kavita";
  users.groups.kavitan = { };
  users.users.kavitan.isSystemUser = true;
  users.users.kavitan.group = "kavitan";
  users.users.kavitan.home = "/var/lib/kavitan";
  users.groups.karakeep = { };
  users.users.karakeep.isSystemUser = true;
  users.users.karakeep.group = "karakeep";
  users.users.karakeep.home = "/var/lib/karakeep";

  # Navidrome Music Server
  services.navidrome.settings.MusicFolder = "/mnt/cirdan/smb/Music";
  services.navidrome.settings.BaseUrl = "";
  services.navidrome.settings.ReverseProxyWhitelist = "${configVars.networking.subnets.cirdan.ip}/32";
  services.navidrome.settings.ReverseProxyUserHeader = "X-Authentik-Username";
  services.navidrome.environmentFile = pkgs.writeText "stack.env" ''
    ND_AUTH_PROXY_AUTO_CREATE_USERS=true
    ND_AUTH_PROXY_DEFAULT_ROLE=USER
  '';

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

  # Bombadil Failover Cert Sync
  sops.secrets."acme-failover-key" = {
    key = "ssh/personal/root_only/acme-failover-key";
    mode = "0600";
  };
  services.rsyncCertSync.sender.enable = true;
  services.rsyncCertSync.sender.vpsHost = configVars.networking.external.bombadil.mainUrl;
  services.rsyncCertSync.sender.vpsSshPort = configVars.networking.ports.tcp.remoteSsh;
  services.rsyncCertSync.sender.sshKeyPath = config.sops.secrets.acme-failover-key.path;

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
