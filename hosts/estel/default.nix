###############################################################################
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
    "hosts/common/optional/services/actual-budget.nix"
    "hosts/common/optional/services/atuin.nix"
    # Audiobookshelf runs on feanor since 2026-10-05, next to its libraries.
    "hosts/common/optional/services/homelab-beszel-hub.nix"
    "hosts/common/optional/services/homelab-beszel-agent.nix"
    # "hosts/common/optional/services/ddclient.nix" # Disabled - HAProxy routes traffic through bombadil
    "hosts/common/optional/services/docker.nix"
    "hosts/common/optional/services/komodo-periphery.nix" # containers visible in Komodo (feanor)
    "hosts/common/optional/services/hedgedoc.nix"
    "hosts/common/optional/services/immich-public-proxy.nix"
    # Immich itself runs natively on feanor (hosts/feanor/default.nix); the
    # public proxy above points there.
    # "hosts/common/optional/services/immich.nix"
    "hosts/common/optional/services/kanidm.nix"
    "hosts/common/optional/services/karakeep.nix"
    # Kavita and Kavitan run on feanor since 2026-10-05, next to their libraries.
    "hosts/common/optional/services/mealie.nix"
    # Disabled 2026-03-04: Navidrome build failure (pkg-config taglib issue), TODO: re-enable when fixed
    # Navidrome runs on feanor since 2026-10-06 (its oauth2-proxy stays here).
    "hosts/common/optional/services/oauth2-proxy.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/paperless.nix"
    "hosts/common/optional/services/seerr.nix"
    "hosts/common/optional/services/systemd-failure-pushover.nix"
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
    "caddy"
    "hedgedoc"
    "immich-public-proxy"
    "kanidm"
    "karakeep-web"
    "mealie"
    # Disabled 2026-03-04: Navidrome build failure
    "oauth2-proxy-navidrome"
    "oauth2-proxy-archerstashvr"
    "oauth2-proxy-comfyui"
    "oauth2-proxy-comfyuimini"
    "oauth2-proxy-delugeweb"
    "oauth2-proxy-flood"
    "oauth2-proxy-invokeai"
    "oauth2-proxy-nzbget"
    "oauth2-proxy-nzbhydra"
    "oauth2-proxy-radarr"
    "oauth2-proxy-sonarr"
    "oauth2-proxy-stashvr"
    "oauth2-proxy-tubearchivist"
    "oauth2-proxy-whisparr"
    "oauth2-proxy-whisparr-eros"
    "oauth2-proxy-seerr"
    "paperless-web"
    "seerr"
  ];

  # Get as much set up with the minimal GPU as possible
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
  hardware.graphics.extraPackages = with pkgs; [
    clinfo # lets you check available OpenCL devices
    vulkan-tools # includes vulkaninfo
  ];

  ## Imports overrides
  # The Beszel hub runs under Podman here; Docker has nothing. Komodo's agent
  # watches Podman through its Docker-compatible socket.
  services.komodoAgent.dockerHost = "unix:///run/podman/podman.sock";
  # The agent's module defaults Docker off when it watches another engine;
  # docker.nix wants it on (also at default priority), so decide it here.
  virtualisation.docker.enable = true;
  # Native OIDC logins through Kanidm (Authentik retires with cirdan).
  services.ssoProvider = {
    budget = "kanidm-oidc";
    hedgedoc = "kanidm-oidc";
    karakeep = "kanidm-oidc";
    mealie = "kanidm-oidc";
    paperless = "kanidm-oidc";
  };
  services.atuin.openRegistration = true;
  # Pinned to unstable 2026-09-07: 26.05's karakeep builds against nodejs 24.19.0, whose
  # node::ObjectWrap cleanup-hook change aborts better-sqlite3's Statement destructor
  # ("Assertion failed: (env) != nullptr"), killing karakeep-workers ~4s after start.
  # Unstable hardcodes nodejs_22 for this. Revert to pkgs.karakeep once 26.05 backports it.
  # Upstream: https://github.com/karakeep-app/karakeep/issues/2989
  services.karakeep.package = pkgs.unstable.karakeep;
  services.karakeep.browser.exe = lib.mkForce "${pkgs.chromium}/bin/chromium";
  services.paperless.configureTika = lib.mkForce false; # This requires building libreoffice and that isn't building

  # Currently-Docker Stuff
  users.groups.karakeep = { };
  users.users.karakeep.isSystemUser = true;
  users.users.karakeep.group = "karakeep";
  users.users.karakeep.home = "/var/lib/karakeep";

  # Homelab Beszel monitoring agent - override hubUrl to use local hub
  # Homelab Beszel monitoring - filesystems and GPU auto-detected
  # Hub runs locally on this machine
  services.homelab-beszel-agent = {
    hubUrl = "http://localhost:8090";
  };

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
    neovim
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

  # OAuth2-proxy instances (Kanidm SSO) for services fronted by this Caddy.
  # A service only uses one once its caddy.nix entry has proxy = "oauth2".
  services.homelab-oauth2-proxy.instances = [
    "archerstashvr"
    "comfyui"
    "comfyuimini"
    "delugeweb"
    "flood"
    "invokeai"
    "nzbget"
    "nzbhydra"
    "radarr"
    "sonarr"
    "navidrome"
    "stashvr"
    "tubearchivist"
    "whisparr"
    "whisparr-eros"
  ];

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$5SGpsUDjjH9wZ61QMwXf0.$C.cQnNS.mmXLEQ34/cqfpU.LXJ0BydbEFr4oukpn8u/";
}
