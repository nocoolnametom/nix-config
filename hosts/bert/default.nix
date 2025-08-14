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
    inputs.hardware.nixosModules.raspberry-pi-4

    ############################## Nginx ######################################
    # ./nginx.nix
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
    "hosts/common/optional/per-user-vpn-setup.nix"
    "hosts/common/optional/services/ddclient.nix"
    "hosts/common/optional/services/deluge.nix"
    "hosts/common/optional/services/flood.nix"
    "hosts/common/optional/services/karakeep.nix"
    "hosts/common/optional/services/navidrome.nix"
    "hosts/common/optional/services/nzbget.nix"
    "hosts/common/optional/services/nzbhydra.nix"
    "hosts/common/optional/services/ombi.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/radarr.nix"
    "hosts/common/optional/services/sickrage.nix"
    "hosts/common/optional/services/sonarr.nix"
    "hosts/common/optional/services/stashapp.nix"
    # "hosts/common/optional/services/ytdl-sub.nix"

    #################### Users to Create ####################
    "home/${configVars.username}/persistence/bert.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # I'm not currently running persistence on the RasPi! RAM is too limited.
  environment.persistence."${configVars.persistFolder}".enable = lib.mkForce false;

  # Enable stash-vr
  services.stashapp.vr-helper.enable = false;
  services.stashapp.vr-helper.stash-host = "https://${configVars.networking.subdomains.stash}.${configVars.domain}";
  sops.secrets."bert-stashapp-api-key" = { };
  sops.templates."stash-vr.conf".content = ''
    STASH_API_KEY=${config.sops.placeholder."bert-stashapp-api-key"}
  '';
  services.stashapp.vr-helper.apiEnvironmentVariableFile = config.sops.templates."stash-vr.conf".path;

  ## Imports overrides

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "bert";
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

  # Use the systemd-boot EFI boot loader.
  boot.tmp.cleanOnBoot = true;
  boot.tmp.useTmpfs = true;
  boot.initrd.systemd.enable = true;

  # Deluge WebUI must be active to send torrents from SickGear!

  # Flood UI
  sops.secrets.flood-user = { };
  sops.secrets.flood-pass = { };
  sops.templates."flood.env".content = ''
    FLOOD_OPTION_DEUSER="${config.sops.placeholder.flood-user}"
    FLOOD_OPTION_DEPASS="${config.sops.placeholder.flood-pass}"
  '';
  services.flood.host = "0.0.0.0";
  systemd.services.flood.serviceConfig.EnvironmentFile = config.sops.templates."flood.env".path;
  services.flood.extraArgs = [
    "--noauth"
    "--dehost=localhost"
    "--deport=${builtins.toString config.services.deluge.config.daemon_port}"
  ];

  # NZBHydra Data Storage
  services.nzbhydra2.dataDir = "/media/g_drive/nzbhydra2";

  # Karakeep Asset Storage
  services.karakeep.extraEnvironment.ASSETS_DIR = "/media/g_drive/karakeep/assets";

  # Navidrome Music Server
  services.navidrome.settings.MusicFolder = "/mnt/Backup/Takeout/${configVars.handle}/Google_Play_Music";
  services.navidrome.settings.BaseUrl = "";
  services.navidrome.settings.ReverseProxyWhitelist = "${configVars.networking.subnets.cirdan.ip}/32";
  services.navidrome.settings.ReverseProxyUserHeader = "X-Authentik-Username";
  services.navidrome.environmentFile = pkgs.writeText "stack.env" ''
    ND_AUTH_PROXY_AUTO_CREATE_USERS=true
    ND_AUTH_PROXY_DEFAULT_ROLE=USER
  '';

  # Bombadil Failover Cert Sync
  sops.secrets."acme-failover-key" = {
    key = "ssh/personal/root_only/acme-failover-key";
    mode = "0600";
  };
  services.rsyncCertSync.enable = true;
  services.rsyncCertSync.vpsHost = configVars.networking.external.bombadil.mainUrl;
  services.rsyncCertSync.vpsSshPort = configVars.networking.ports.tcp.remoteSsh;
  services.rsyncCertSync.sshKeyPath = config.sops.secrets.acme-failover-key.path;

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

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
