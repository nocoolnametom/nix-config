###############################################################################
#
#  Glorfindel - Linode 4GB
#  NixOS running on Linode 4GB instance (Qemu/KVM)
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
  socialUrl = configVars.networking.external.glorfindel.mainUrl;
in
{
  imports =
    [
      ######################## Every Host Needs This ############################
      ./hardware-configuration.nix

      ############################## Nginx ######################################
      ./nginx.nix

      ########################### Impermanence ##################################
      ./persistence.nix
      # There might be an option to reformat the drive with btrfs and delete root
      # on shutdown, but I'm not sure how to do that yet.

      ############################## Stylix #####################################
      # inputs.stylix.nixosModules.stylix # No GUI on Linode
    ]
    ++ (map configLib.relativeToRoot [
      #################### Required Configs ####################
      "hosts/common/core"

      #################### Host-specific Optional Configs ####################
      "hosts/common/optional/services/openssh.nix"
      "hosts/common/optional/services/mastodon.nix"
      "hosts/common/optional/services/postgresql.nix"
      "hosts/common/optional/services/elasticsearch.nix"
      "hosts/common/optional/services/mailserver.nix"
      "hosts/common/optional/linode.nix"

      #################### Users to Create ####################
      "home/${configVars.username}/persistence/glorfindel.nix"
      "hosts/common/users/${configVars.username}"
    ]);

  # I'm not currently running persistence on the Linode as I need to figure out
  # how to handle it via BtrFS and not via TmpFS as the RAM is very limited.
  environment.persistence."${configVars.persistFolder}".enable = lib.mkForce false;

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking.hostName = configVars.networking.external.glorfindel.name;
  networking.hosts."${configVars.networking.external.glorfindel.ip}" = [
    socialUrl
    "www.${socialUrl}"
  ];
  networking.useDHCP = false; # I'm using a static IP through Linode
  networking.enableIPv6 = true;
  networking.usePredictableInterfaceNames = false; # Linode changes the interface name often
  networking.interfaces.eth0.useDHCP = true; # Linode uses DHCP for the private IP
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
  networking.firewall.allowPing = true; # Linode's LISH console requires ping

  # Mastodon setup
  services.mastodon.localDomain = socialUrl;

  # Use the Grub 2 boot loader
  boot.loader.grub.enable = true;
  boot.loader.grub.forceInstall = true; # Linode uses partitionless disks
  boot.loader.grub.device = "nodev"; # Linode's LISH console requires this
  boot.loader.timeout = 0; # Linode's LISH console requires this
  boot.loader.grub.copyKernels = true;
  boot.loader.grub.fsIdentifier = "label";
  boot.loader.grub.extraConfig = ''
    serial --speed=19200 --unit=0 --word=8 --parity=no --stop=1;
    terminal_input serial;
    terminal_output serial;
  '';
  boot.kernelParams = [
    "console=ttyS0,19200n8" # Linode's LISH console requires this
  ];

  # Cleanup on boot
  boot.tmp.cleanOnBoot = true;
  boot.tmp.useTmpfs = true;
  boot.initrd.systemd.enable = true;

  time.timeZone = "America/Denver";

  # Prevent systemd from logging too much
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    RuntimeMaxUse=500M
  '';

  # Disable the xserver
  services.xserver.enable = false;

  # Use sudo without a password
  security.sudo.wheelNeedsPassword = false;

  # Enable AppArmor
  security.apparmor.enable = true;

  # Fix VSCode remote
  programs.nix-ld.enable = true;

  # Enable the Time Protocol
  services.ntp.enable = true;

  # OpenSSH
  services.openssh.ports = [
    configVars.networking.ports.tcp.remoteSsh # Only accessible via remote SSH port
  ];
  services.openssh.openFirewall = true;

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
    "nixpkgs-unstable"
    "--update-input"
    "home-manager"
    "--no-write-lock-file"
    "-L" # print build logs
  ];

  system.stateVersion = "23.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
