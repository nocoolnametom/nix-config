###############################################################################
#
#  Fedibox - AWS EC2 Instance
#  NixOS running on AWS EC2 Nano
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
  socialUrl = configVars.networking.external.fedibox.mainUrl;
  hostName = configVars.networking.external.fedibox.name;
in
{
  # @TODO: THIS IS A WORK IN PROGRESS - JUST A COPY OF BOMBADIL FOR NOW, UPDATE WITH EC2 SPECIFIC CONFIG
  imports = [
    ######################## Every Host Needs This ############################
    ./hardware-configuration.nix

    ############################## Nginx ######################################
    ./nginx.nix

    ########################### Impermanence ##################################
    ./persistence.nix

    ############################## Stylix #####################################
    # inputs.stylix.nixosModules.stylix # No GUI on AWS
  ]
  ++ (map configLib.relativeToRoot [
    #################### Required Configs ####################
    "hosts/common/core"

    #################### Host-specific Optional Configs ####################
    "hosts/common/optional/services/akkoma.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/postgresql.nix"
    "hosts/common/optional/services/elasticsearch.nix"
    "hosts/common/optional/services/mailserver.nix"
    # "hosts/common/optional/linode.nix" # Until removed from EC2 we can't use Linode settings
    "hosts/common/optional/nostr.nix"

    #################### Users to Create ####################
    "home/${configVars.username}/persistence/${hostName}.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # The networking hostname is used in a lot of places, such as secret retrieval!
  # networking.hostName = hostName; # Technically, the hostname should be set within AWS
  networking.hosts."${configVars.networking.external.fedibox.ip}" = [
    socialUrl
    "www.${socialUrl}"
  ];

  environment.systemPackages = [
    (pkgs.vim_configurable.customize {
      name = "vim";
      vimrcConfig.packages.myplugins = {
        start = [
          pkgs.vimPlugins.vim-nix
          pkgs.vimPlugins.vim-trailing-whitespace
          pkgs.vimPlugins.vim-elixir
        ];
        opt = [ ];
      };
      vimrcConfig.customRC = ''
        set nocompatible
        set softtabstop=0 smarttab
        set backspace=indent,eol,start
        set smartcase
        set mouse=a
        set number relativenumber
        :imap jj <Esc>
        autocmd InsertEnter * :set norelativenumber
        autocmd InsertLeave * :set relativenumber
        :nmap <C-s> :w<CR>
        :imap <C-s> <Esc>:w<CR>a
      '';
    })
    pkgs.awscli
    pkgs.imagemagick # For Pleroma uploads
    pkgs.exiftool # For Pleroma uploads
    pkgs.ffmpeg # For Pleroma uploads
    pkgs.element-web
    pkgs.s3fs
    pkgs.fuse
  ];

  networking.useDHCP = false; # I'm using a static IP
  networking.enableIPv6 = true;
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    80 # HTTP
    443 # HTTPS
    configVars.networking.ports.tcp.remoteSsh
    configVars.networking.ports.tcp.localSsh
  ];
  networking.firewall.allowedUDPPorts = [
    443 # HTTPS
  ];
  networking.firewall.allowPing = true;

  # Akkoma Setup
  services.akkoma.enable = false;
  services.akkoma.config.":pleroma"."Pleroma.Web.Endpoint".url.host = socialUrl;
  services.akkoma.config.":pleroma".":instance".name =
    configVars.networking.external.fedibox.niceName;
  services.akkoma.config.":pleroma".":instance".description =
    "A single-user instance for ${configVars.handles.mastodon}";

  # Postgres Backup
  services.postgresqlBackup.enable = true;
  services.postgresqlBackup.backupAll = true;
  services.postgresqlBackup.location = "/mnt/s3mount/backups/postgresql";
  services.postgresqlBackup.startAt = lib.mkForce "weekly";

  # Nostr Setup
  programs.nostr.enable = true;
  programs.nostr.domain = configVars.domain;

  # Prevent systemd from logging too much
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    RuntimeMaxUse=500M
  '';

  # Disable the xserver
  services.xserver.enable = lib.mkForce false;

  # Use sudo without a password
  security.sudo.wheelNeedsPassword = false;

  # Enable AppArmor
  security.apparmor.enable = true;

  # OpenSSH
  services.openssh.ports = [
    configVars.networking.ports.tcp.remoteSsh # Only accessible via remote SSH port
  ];
  services.openssh.openFirewall = true;
  users.users.root.openssh.authorizedKeys.keys = [
    # Make sure to update this with whatever the deployed EC2 instance provides as a public key!!
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCXkF/YOCamtWqau5kLr2OpHC6ogpqLPNAnG9qijCpf/OmcW2ejA4f3zbZMDiS/VpOsxCS+6qFZN7n27/P8NeJle5rHJfEuXOeqVosIDwj6Xe6ikFr0DPdV7p/3noVWOAVn+MwtM4zIA2ec8jS02frCkAEHH+DfcYv/zUuCE8+U9d4CldUAtWnvJcmuQ/02fydteXGD0dNJWego27qaDzS1Iy+gfDkoVQKXR12BCCW54KImyHn0lPWcEMNbgg7Zd1hNTMVDnxpOCz77q1j3bviH7FpwA8Qmphd2VYXPRp6GW6I28hO7mXc1aL4W9YIHNNasyaxtAIq4uENAs7m7ngn9 nocoolnametom-com-pleroma"
  ];

  # Fail2Ban
  services.fail2ban.enable = true;

  # Automatic Upgrades
  system.autoUpgrade.enable = true;
  system.autoUpgrade.flake = inputs.self.outPath;
  system.autoUpgrade.flags = [
    "--update-input"
    "disposable-email-domains"
    "--update-input"
    "nixpkgs"
    "--update-input"
    "nixpkgs-stable"
    "--update-input"
    "nixpkgs-unstable"
    "--no-write-lock-file"
    "-L" # print build logs
  ];

  time.timeZone = "America/Los_Angeles";

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
