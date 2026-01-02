###############################################################################
#
#  Durin - replacement for Bert
#  Copy/adapted from `hosts/bert/default.nix`.
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
let
  stashPath = "/arkenstone/stash";
in
{
  imports = [
    # Hardware config: replace with a copy of the correct hardware-configuration.nix
    ./hardware-configuration.nix

    # Persistence (adjust as needed)
    ./persistence.nix

    ############################ Lanzaboote ###################################
    inputs.lanzaboote.nixosModules.lanzaboote # Must also use the config below
  ]
  ++ (map configLib.relativeToRoot [
    "hosts/common/core"

    # Lanzaboote Secure Bootloader (like estel)
    "hosts/common/optional/lanzaboote.nix"

    # Copy the same optional service modules as bert; enable/disable as you prefer
    "hosts/common/optional/per-user-vpn-setup.nix"
    "hosts/common/optional/services/deluge.nix"
    "hosts/common/optional/services/flood.nix"
    "hosts/common/optional/services/nzbget.nix"
    "hosts/common/optional/services/nzbhydra.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/pinchflat.nix"
    "hosts/common/optional/services/radarr.nix"
    "hosts/common/optional/services/sickrage.nix"
    "hosts/common/optional/services/sonarr.nix"
    "hosts/common/optional/services/stash.nix"

    # Create per-user persistence entry for durin
    "home/${configVars.username}/persistence/durin.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # Keep persistence off by default; enable if this machine will hold data
  environment.persistence."${configVars.persistFolder}".enable = lib.mkForce false;

  # Stash service configuration
  users.users.${config.services.stash.user}.extraGroups =
    lib.optionals config.services.nzbget.enable
      [
        config.services.nzbget.group
        "media"
      ];

  # Stash VR helper configuration - multiple instances
  services.stash.vr-helper.enable = true;
  services.stash.vr-helper.hosts.external.stashUrl =
    "https://${configVars.networking.subdomains.stash}.${configVars.domain}";
  services.stash.vr-helper.hosts.external.port = configVars.networking.ports.tcp.stashvr;

  # Stash library paths configuration
  services.stash.settings.stash =
    let
      regularPaths = paths: map (path: { inherit path; }) paths;
      imageOnlyPaths =
        paths:
        map (path: {
          inherit path;
          excludevideo = true;
        }) paths;
      videoOnlyPaths =
        paths:
        map (path: {
          inherit path;
          excludeimage = true;
        }) paths;
    in
    (regularPaths [
      "${stashPath}/library/needswork"
    ])
    ++ (imageOnlyPaths [
      "${stashPath}/library/images"
    ])
    ++ (videoOnlyPaths [
      "${stashPath}/library/anime"
      "${stashPath}/library/unorganized"
      "${stashPath}/library/videos"
      "${stashPath}/library/vr"
    ]);
  services.stash.settings.blobs_path = "${stashPath}/blobs";
  services.stash.settings.cache = "${stashPath}/cache";
  services.stash.settings.database = "${stashPath}/db/stash-go.sqlite";
  services.stash.settings.generated = "${stashPath}/generated";
  services.stash.settings.plugins_path = "${stashPath}/plugins";
  services.stash.settings.scrapers_path = "${stashPath}/scrapers";

  # Authorized keys: copy/replace the pubkey file if needed
  users.users.${configVars.username}.openssh.authorizedKeys.keyFiles = [
    ./stash-conversion.pub
  ];

  # Networking basics - update IPs and names for durin
  networking = {
    hostName = "durin";
    nameservers = [
      "1.1.1.1#one.one.one.one"
      "1.0.0.1#one.one.one.one"
      "8.8.8.8#eight.eight.eight.eight"
    ];
    networkmanager.enable = true;
    enableIPv6 = true;
    firewall.enable = false;
    firewall.allowedTCPPorts = [
      80
      443
      configVars.networking.ports.tcp.remoteSsh
      configVars.networking.ports.tcp.localSsh
    ];
    firewall.allowedUDPPorts = [ 443 ];
    firewall.allowPing = true;
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

  boot.tmp.cleanOnBoot = true;
  boot.tmp.useTmpfs = true;
  boot.initrd.systemd.enable = true;

  environment.systemPackages = with pkgs; [
    claude-code
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

  # Flood secrets placeholder
  sops.secrets.flood-user = { };
  sops.secrets.flood-pass = { };
  sops.templates."flood.env".content = ''
    FLOOD_OPTION_DEUSER="${config.sops.placeholder.flood-user}"
    FLOOD_OPTION_DEPASS="${config.sops.placeholder.flood-pass}"
  '';

  services.flood.host = "0.0.0.0";
  systemd.services.flood.serviceConfig.EnvironmentFile = config.sops.templates."flood.env".path;

  # Example storage mounts - adjust to durin's disks
  services.nzbhydra2.dataDir = "/arkenstone/nzbhydra2";

  # Set up media directories with correct permissions for shared access
  # The 2775 mode sets setgid bit so new files inherit the media group
  systemd.tmpfiles.rules = [
    "d /arkenstone/deluge 2775 deluge media -"
    "d /arkenstone/deluge/torrents 2775 deluge media -"
    "d /arkenstone/deluge/Downloads 2775 deluge media -"
    "d /arkenstone/deluge/Finished 2775 deluge media -"
    "d /arkenstone/nzbget 2775 nzbget media -"
    "d /arkenstone/nzbget/dest 2775 nzbget media -"
    "d /arkenstone/nzbget/nzb 2775 nzbget media -"
    "d /arkenstone/nzbget/scripts 2775 nzbget media -"
    # Add any other download/media directories that need shared access
  ];

  # Security defaults
  security.sudo.wheelNeedsPassword = false;
  security.apparmor.enable = true;
  services.fail2ban.enable = false;

  # Enable nix-ld for VSCode remote
  programs.nix-ld.enable = true;

  system.stateVersion = "25.05";

  # Root password placeholder (keep, remove, or replace as you prefer)
  users.users.root.initialHashedPassword = "";
}
