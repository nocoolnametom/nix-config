###############################################################################
#
#  Estel - Beelink Mini PC
#  NixOS running on Beelink SER5 Mini PC
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

    ############################## Nginx ######################################
    ./caddy.nix

    ########################### Impermanence ##################################
    ./persistence.nix

    ############################ Lanzaboote ###################################
    inputs.lanzaboote.nixosModules.lanzaboote # Must also use the config below

    ############################## Stylix #####################################
    # inputs.stylix.nixosModules.stylix # No GUI
  ]
  ++ (map configLib.relativeToRoot [
    #################### Required Configs ####################
    "hosts/common/core"

    #################### Host-specific Optional Configs ####################
    "hosts/common/optional/cross-compiling.nix"
    "hosts/common/optional/gpg-agent.nix" # GPG-Agent with SSH support
    "hosts/common/optional/homelab-ca.nix" # Install homelab CA certificate
    "hosts/common/optional/homelab-status-page.nix" # Homelab status page
    "hosts/common/optional/lanzaboote.nix" # Lanzaboote Secure Bootloader
    "hosts/common/optional/services/netdata-parent.nix" # Netdata monitoring parent
    "hosts/common/optional/services/netdata-caddy.nix" # Netdata Caddy integration
    "hosts/common/optional/services/netdata-collectors.nix" # Service monitoring collectors
    "hosts/common/optional/services/actual-budget.nix"
    "hosts/common/optional/services/audiobookshelf.nix"
    # "hosts/common/optional/services/ddclient.nix" # Disabled - HAProxy routes traffic through bombadil
    "hosts/common/optional/services/docker.nix"
    "hosts/common/optional/services/hedgedoc.nix"
    "hosts/common/optional/services/immich-public-proxy.nix"
    "hosts/common/optional/services/immich.nix"
    "hosts/common/optional/services/kanidm.nix"
    "hosts/common/optional/services/karakeep.nix"
    "hosts/common/optional/services/kavita.nix" # Turn on and turn off portainers when 0.8.8 is released!
    "hosts/common/optional/services/mealie.nix"
    # Disabled 2026-03-04: Navidrome build failure (pkg-config taglib issue), TODO: re-enable when fixed
    # "hosts/common/optional/services/navidrome.nix"
    "hosts/common/optional/services/oauth2-proxy.nix"
    "hosts/common/optional/services/ombi.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/paperless.nix"
    "hosts/common/optional/services/systemd-failure-pushover.nix"
    "hosts/common/optional/services/tailscale.nix"
    "hosts/common/optional/services/wireguard-bombadil-estel.nix"
    "hosts/common/optional/services/work-block.nix"
    "hosts/common/optional/dns-over-tls.nix" # TODO: band-aid for DNS failures — investigate root cause and remove
    "hosts/common/optional/foreign-binaries.nix"
    "hosts/common/optional/yubikey.nix"
    # tube-archivist via docker?

    #################### Users to Create ####################
    "home/${configVars.username}/persistence/estel.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # Send alerts on systemd service failures
  services.systemd-failure-alert.additional-services = [
    "actual-budget"
    "audiobookshelf"
    "caddy"
    "hedgedoc"
    "immich-public-proxy"
    "immich-server"
    "kanidm"
    "karakeep-web"
    "kavita"
    "kavitan"
    "mealie"
    # Disabled 2026-03-04: Navidrome build failure
    # "navidrome"
    # "oauth2-proxy-navidrome"
    "oauth2-proxy-ombi"
    "ombi"
    "paperless-web"
  ];

  # Get as much set up with the minimal GPU as possible
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.graphics.extraPackages = with pkgs; [
    clinfo # lets you check available OpenCL devices
    vulkan-tools # includes vulkaninfo
  ];

  ## Imports overrides
  services.karakeep.package = lib.mkForce pkgs.unstable.karakeep;
  services.karakeep.browser.exe = lib.mkForce "${pkgs.unstable.chromium}/bin/chromium";
  services.paperless.configureTika = lib.mkForce false; # This requires building libreoffice and that isn't building
  services.immich.package = lib.mkForce pkgs.unstable.immich;
  services.immich.mediaLocation = "/mnt/cirdan/smb/Immich/uploads/";
  services.immich.machine-learning.enable = false; # For now this seems too intensive for the little mini pc

  # Currently-Docker Stuff
  # Can replase kavita users below with kavita module when 0.8.8 is released!
  services.kavita.package = lib.mkForce pkgs.bleeding.kavita;
  services.kavitan.package = lib.mkForce pkgs.bleeding.kavita;
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

  # Navidrome Music Server - Disabled 2026-03-04: Build failure
  # Configuration is conditional based on SSO provider (authentik vs kanidm-oauth2)
  # services.navidrome.settings = {
  #   MusicFolder = "/mnt/cirdan/smb/Music";
  #   BaseUrl = "";
  #   # OAuth2-proxy runs on estel (same host), Authentik runs on cirdan
  #   ReverseProxyWhitelist =
  #     if config.services.ssoProvider.navidrome or "authentik" == "kanidm-oauth2" then
  #       "${configVars.networking.subnets.estel.ip}/32"
  #     else
  #       "${configVars.networking.subnets.cirdan.ip}/32";
  #   # Header name differs between OAuth2-proxy and Authentik
  #   ReverseProxyUserHeader =
  #     if config.services.ssoProvider.navidrome or "authentik" == "kanidm-oauth2" then
  #       "X-Forwarded-User"
  #     else
  #       "X-Authentik-Username";
  # };
  # services.navidrome.environmentFile = pkgs.writeText "stack.env" ''
  #   ND_AUTH_PROXY_AUTO_CREATE_USERS=true
  #   ND_AUTH_PROXY_DEFAULT_ROLE=USER
  # '';

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "estel";
    wireless.enable = false;
    networkmanager.enable = true;
    networkmanager.wifi.backend = "iwd";
    enableIPv6 = true;
    # Static IPv6 address for reliable remote access
    # Using ::50 to differentiate from bert's ::42
    interfaces.end0.ipv6.addresses = [
      {
        address = "2603:7081:7e3f:1b92::50"; # Static IPv6 for estel
        prefixLength = 64;
      }
    ];
    # Firewall disabled - ISP blocks all incoming connections (CGNAT on both IPv4 and IPv6)
    # estel initiates WireGuard connection to bombadil, so only outbound connections needed
    firewall.enable = false;
  };

  # Disable IPv6 privacy extensions to prevent temporary address rotation
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.use_tempaddr" = lib.mkForce 0;
    "net.ipv6.conf.end0.use_tempaddr" = lib.mkForce 0;
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
  ];

  # Bombadil Failover Cert Sync - DISABLED (HAProxy now routes traffic, no cert sync needed)
  # sops.secrets."acme-failover-key" = {
  #   key = "ssh/personal/root_only/acme-failover-key";
  #   mode = "0600";
  # };
  # services.rsyncCertSync.sender.enable = true;
  # services.rsyncCertSync.sender.vpsHost = configVars.networking.external.bombadil.mainUrl;
  # services.rsyncCertSync.sender.vpsSshPort = configVars.networking.ports.tcp.remoteSsh;
  # services.rsyncCertSync.sender.sshKeyPath = config.sops.secrets.acme-failover-key.path;
  # services.rsyncCertSync.sender.vpsTargetPath = "/var/lib/acme-failover";

  # fail2ban disabled - no direct SSH access (key-only via bombadil proxy), ISP blocks incoming
  services.fail2ban.enable = false;

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$5SGpsUDjjH9wZ61QMwXf0.$C.cQnNS.mmXLEQ34/cqfpU.LXJ0BydbEFr4oukpn8u/";
}
