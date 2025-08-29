###############################################################################
#
#  Barliman - Desktop
#  NixOS running on Personal Framework Desktop Machine - Dual Booting
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
    inputs.hardware.nixosModules.framework-desktop-amd-ai-max-300-series

    ########################### Impermanence ##################################
    # ./persistence.nix

    ############################## Stylix #####################################
    inputs.stylix.nixosModules.stylix
  ]
  ++ (map configLib.relativeToRoot [
    #################### Required Configs ####################
    "hosts/common/core"

    #################### Host-specific Optional Configs ####################
    "hosts/common/optional/boot/regular_boot.nix" # Don't use with Lanzaboote!
    # "hosts/common/optional/lanzaboote.nix" # Lanzaboote Secure Bootloader
    "hosts/common/optional/services/comfyui/default.nix"
    "hosts/common/optional/services/flatpak.nix"
    "hosts/common/optional/services/ollama.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/pipewire.nix" # audio
    "hosts/common/optional/services/printing.nix"
    "hosts/common/optional/services/stashapp.nix"
    "hosts/common/optional/cross-compiling.nix"
    "hosts/common/optional/jovian.nix"
    "hosts/common/optional/steam.nix"
    "hosts/common/optional/stylix.nix"

    #################### Users to Create ####################
    # "home/${configVars.username}/persistence/barliman.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # Comfy Models
  # You must on the initial usage of the comfyui optional module NOT load any remote models
  # so that the tokens are injected into the nix-daemon systemd job
  # services.comfyui.models = lib.mkForce []; # Use this before the sops-nix secrets are loaded
  services.comfyui.symlinkPaths = {
    checkpoints = "/var/lib/ai-models/stable-diffusion/linked/checkpoints";
    loras = "/var/lib/ai-models/stable-diffusion/linked/loras";
  };
  services.comfyui.comfyuimini.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
  hardware.bluetooth.settings.General.Experimental = true;
  hardware.bluetooth.settings.Policy.AutoEnable = true;

  # Open-WebUI is a web-frontend for chatting with ollama
  services.open-webui.enable = true;
  services.open-webui.host = "0.0.0.0";
  sops.templates."open-webui.conf".content = ''
    ENABLE_OAUTH_SIGNUP=true
    OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
    OAUTH_PROVIDER_NAME=Authentik
    OPENID_PROVIDER_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/${
      config.sops.placeholder."open-webui-slug"
    }/.well-known/openid-configuration
    OAUTH_CLIENT_ID=${config.sops.placeholder."open-webui-clientid"}
    OAUTH_CLIENT_SECRET=${config.sops.placeholder."open-webui-clientsecret"}
    OAUTH_SCOPES=openid email profile
    OPENID_REDIRECT_URI=https://${configVars.networking.subdomains.openwebui}.${configVars.domain}/oauth/oidc/callback
  '';
  services.open-webui.environmentFile = config.sops.templates."open-webui.conf".path;

  # While this is a Jovian machine, it's NOT a SteamDeck
  jovian.devices.steamdeck.enable = lib.mkForce false;
  jovian.steamos.enableBluetoothConfig = true;
  environment.plasma6.excludePackages = with pkgs; [
    kdePackages.baloo # File search than can take a lot of resources to index
    kdePackages.baloo-widgets # Widgets for using baloo
    kdePackages.elisa # Simple music player aiming to provide a nice experience for its users
    kdePackages.kdepim-runtime # Akonadi agents and resources
    kdePackages.kmahjongg # KMahjongg is a tile matching game for one or two players
    kdePackages.kmines # KMines is the classic Minesweeper game
    kdePackages.konversation # User-friendly and fully-featured IRC client
    kdePackages.kpat # KPatience offers a selection of solitaire card games
    kdePackages.ksudoku # KSudoku is a logic-based symbol placement puzzle
    kdePackages.ktorrent # Powerful BitTorrent client
    mpv
  ];

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "barliman";
    networkmanager.enable = true;
    networkmanager.wifi.backend = "iwd";
    enableIPv6 = true;
    firewall.enable = true;
    firewall.allowPing = true;
  };

  environment.systemPackages = with pkgs; [
    appimage-run
    brave
    glibcLocales
    cmake
    steam-rom-manager
    gnumake
    nodejs
    p7zip
    samba
    screen
    unrar
    unzip
    vim
    wget
  ];

  # Run AppImages directly
  programs.appimage.binfmt = true;

  # Security
  security.sudo.wheelNeedsPassword = false;
  security.apparmor.enable = true;
  services.openssh.openFirewall = true;
  services.fail2ban.enable = true;

  # Fixes VSCode remote
  programs.nix-ld.enable = true;

  # Build documentation
  documentation.nixos.enable = false;

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
