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
  imports =
    [
      ######################## Every Host Needs This ############################
      ./hardware-configuration.nix

      ########################## Hardware Modules ###############################
      inputs.hardware.nixosModules.raspberry-pi-4

      ############################## SMB Shares #################################
      ./smb-shares.nix

      ############################## Nginx ######################################
      ./nginx.nix

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
      # "hosts/common/optional/determinate.nix" # Tends to force compilation of kernels
      # Calibre is broken on raspi architecture! 2024-10-18
      # "hosts/common/optional/services/calibre/default.nix"
      "hosts/common/optional/services/ddclient.nix"
      # "hosts/common/optional/services/deluge.nix"
      # "hosts/common/optional/services/flood.nix"
      # "hosts/common/optional/services/maestral.nix"
      "hosts/common/optional/services/navidrome.nix"
      "hosts/common/optional/services/nzbget.nix"
      "hosts/common/optional/services/ombi.nix"
      "hosts/common/optional/services/openssh.nix"
      "hosts/common/optional/services/radarr.nix"
      # "hosts/common/optional/services/sauronsync.nix"
      "hosts/common/optional/services/sickrage.nix"
      "hosts/common/optional/services/stashapp.nix"
      # "hosts/common/optional/services/ytdl-sub.nix"
      "hosts/common/optional/services/kanidm.nix"

      #################### Users to Create ####################
      "home/${configVars.username}/persistence/bert.nix"
      "hosts/common/users/${configVars.username}"
    ]);

  # I'm not currently running persistence on the RasPi! RAM is too limited.
  environment.persistence."${configVars.persistFolder}".enable = lib.mkForce false;

  # Enable stash-vr
  services.stashapp.vr-helper.enable = false;
  services.stashapp.vr-helper.stash-host = "https://${configVars.networking.subdomains.stash}.${configVars.domain}";
  sops.secrets = {
    "bert-stashapp-api-key" = { };
  };
  sops.templates."stash-vr.conf".content = ''
    STASH_API_KEY=${config.sops.placeholder."bert-stashapp-api-key"}
  '';
  services.stashapp.vr-helper.apiEnvironmentVariableFile = config.sops.templates."stash-vr.conf".path;

  ## Imports overrides

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "bert";
    nameservers = [ "8.8.8.8" ];
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

  # Navidrome Music Server
  services.navidrome.settings.MusicFolder = "/mnt/Backup/Takeout/${configVars.handle}/Google_Play_Music";

  # Security
  security.sudo.wheelNeedsPassword = false;
  security.apparmor.enable = true;
  services.fail2ban.enable = true;

  # Fixes VSCode remote
  programs.nix-ld.enable = true;

  # Build documentation
  documentation.nixos.enable = false;

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
