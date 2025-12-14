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
    "hosts/common/optional/services/stashapp.nix"

    # Create per-user persistence entry for durin
    "home/${configVars.username}/persistence/durin.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # Keep persistence off by default; enable if this machine will hold data
  environment.persistence."${configVars.persistFolder}".enable = lib.mkForce false;

  # Stash VR helper: update secret names and hostnames as needed
  services.stashapp.vr-helper.enable = false;
  services.stashapp.vr-helper.stash-host = "https://${configVars.networking.subdomains.stash}.${configVars.domain}";
  sops.secrets."durin-stashapp-api-key" = { };
  sops.templates."stash-vr.conf".content = ''
    STASH_API_KEY=${config.sops.placeholder."durin-stashapp-api-key"}
  '';
  services.stashapp.vr-helper.apiEnvironmentVariableFile = config.sops.templates."stash-vr.conf".path;

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

  # Security defaults
  security.sudo.wheelNeedsPassword = false;
  security.apparmor.enable = true;
  services.fail2ban.enable = false;

  system.stateVersion = "25.05";

  # Root password placeholder (keep, remove, or replace as you prefer)
  users.users.root.initialHashedPassword = "";
}
