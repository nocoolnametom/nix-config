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
    ]
    ++ (map configLib.relativeToRoot [
      #################### Required Configs ####################
      "hosts/common/core"

      #################### Host-specific Optional Configs ####################
      "hosts/common/optional/services/akkoma.nix"
      "hosts/common/optional/services/openssh.nix"
      "hosts/common/optional/services/mastodon.nix"
      "hosts/common/optional/services/postgresql.nix"
      "hosts/common/optional/services/elasticsearch.nix"
      "hosts/common/optional/services/mailserver.nix"
      "hosts/common/optional/linode.nix"
      "hosts/common/optional/nostr.nix"

      #################### Users to Create ####################
      "home/${configVars.username}/persistence/${hostName}.nix"
      "hosts/common/users/${configVars.username}"
    ]);

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking.hostName = hostName;
  networking.hosts."${configVars.networking.external.fedibox.ip}" = [
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
  services.mastodon.webProcesses = 0; # This is the WEB_CONCURRENCY env variable for Puma, 0 is a single process
  services.mastodon.sidekiqThreads = 10; # This seems about right

  # Limit Elasticsearch Memory Usage - Minimum and Maximum
  services.elasticsearch.extraJavaOptions = [
    "-Xms128m"
    "-Xmx256m"
  ];

  time.timeZone = "America/Los_Angeles";

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
  # Use Chrony instead of NTP for a virtualized environment
  services.chrony.enable = true;
  services.chrony.enableNTS = true;
  services.chrony.servers = [ "time.cloudflare.com" ];

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
    "nixpkgs-stable"
    "--update-input"
    "nixpkgs-unstable"
    "--no-write-lock-file"
    "-L" # print build logs
  ];

  system.stateVersion = "24.11";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
