###############################################################################
#
#  Bombadil - Linode 4GB
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
  exmormonSocialUrl = "exmormon.social";
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

      ############################## Stylix #####################################
      # inputs.stylix.nixosModules.stylix # No GUI on Linode

      #TODO move bombadil to disko
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
      "hosts/common/users/tdoggett"
      "home/tdoggett/bombadil/persistence.nix"
    ]);

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking.hostName = "bombadil";
  networking.hosts."${configVars.bombadilIpAddress}" = [
    exmormonSocialUrl
    "www.${exmormonSocialUrl}"
  ];
  networking.useDHCP = false; # I'm using a static IP through Linode
  networking.enableIPv6 = true;
  networking.usePredictableInterfaceNames = false; # Linode changes the interface name often
  networking.interfaces.eth0.useDHCP = true; # Linode uses DHCP for the private IP
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    80 # HTTP
    443 # HTTPS
    2222 # SSH
    22 # SSH
  ];
  networking.firewall.allowedUDPPorts = [
    443 # HTTPS
  ];
  networking.firewall.allowPing = true; # Linode's LISH console requires ping

  # Mastodon setup
  services.mastodon.localDomain = exmormonSocialUrl;

  boot.initrd.systemd.enable = true;

  time.timeZone = "America/Chicago";

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
  services.openssh.ports = [ 2222 ];
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

  system.stateVersion = "24.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
