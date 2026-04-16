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
  ]
  ++ (map configLib.relativeToRoot [
    #################### Required Configs ####################
    "hosts/common/core"

    #################### Host-specific Optional Configs ####################
    "hosts/common/optional/boot/regular_boot.nix" # Don't use with Lanzaboote!
    "hosts/common/optional/homelab-ca.nix" # Install homelab CA certificate
    "hosts/common/optional/homelab-status-page.nix" # Homelab status page
    "hosts/common/optional/services/homelab-beszel-agent.nix" # Homelab Beszel monitoring agent
    # "hosts/common/optional/lanzaboote.nix" # Lanzaboote Secure Bootloader
    "hosts/common/optional/gpg-agent.nix" # GPG-Agent with SSH support
    # "hosts/common/optional/services/eden.nix" # Temporarily disabled - tzdb source is down
    "hosts/common/optional/services/flatpak.nix"
    "hosts/common/optional/services/ollama.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/open-webui.nix"
    "hosts/common/optional/services/pipewire.nix" # audio
    "hosts/common/optional/services/printing.nix"
    "hosts/common/optional/services/podman.nix"
    "hosts/common/optional/services/systemd-failure-pushover.nix"
    "hosts/common/optional/services/work-block.nix"
    "hosts/common/optional/amdgpu_top.nix"
    "hosts/common/optional/cross-compiling.nix"
    "hosts/common/optional/jovian.nix"
    "hosts/common/optional/nvtop.nix"
    "hosts/common/optional/scanning.nix"
    "hosts/common/optional/stylix.nix"
    "hosts/common/optional/bluetooth.nix"
    "hosts/common/optional/foreign-binaries.nix"
    "hosts/common/optional/steam.nix"

    #################### Users to Create ####################
    # "home/${configVars.username}/persistence/barliman.nix"
    "hosts/common/users/${configVars.username}"

    # Temporary empty modules to help pass rebuild errors
    "hosts/barliman/logindhelper.nix"
  ]);

  # Send alerts on systemd service failures
  services.systemd-failure-alert.additional-services = [
    "ollama"
    "open-webui"
  ];

  # Using Rocm instead of Cuda since AMD APU/GPU
  hardware.nvidia-container-toolkit.enable = lib.mkForce false;
  nixpkgs.config.cudaSupport = lib.mkForce false;
  nixpkgs.config.cudnnSupport = lib.mkForce false;
  nixpkgs.config.rocmSupport = true;

  # Open-WebUI is a web-frontend for chatting with ollama
  services.open-webui.package = pkgs.stable.open-webui;
  services.ollama.package = pkgs.unstable.ollama-rocm;
  services.ollama.acceleration = "rocm";
  services.ollama.models = "/var/lib/ai-models/ollama";
  services.ollama.environmentVariables.OLLAMA_LLAMA_GPU_LAYERS = "100";
  services.ollama.environmentVariables.OLLAMA_GPU_OVERHEAD = "1";
  services.ollama.environmentVariables.HCC_AMDGPU_TARGET = "gfx1151";
  services.ollama.environmentVariables.LD_LIBRARY_PATH = "/run/current-system/sw/lib";
  services.ollama.rocmOverrideGfx = "11.5.1";
  systemd.services.ollama.serviceConfig.UnsetEnvironment = "HIP_VISIBLE_DEVICES ROCR_VISIBLE_DEVICES";

  # Bluetooth - Framework Desktop extras (base settings from bluetooth.nix)
  hardware.bluetooth.settings.General.Experimental = true;
  hardware.bluetooth.settings.Policy.AutoEnable = true;

  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # While this is a Jovian machine, it's NOT a SteamDeck
  jovian.devices.steamdeck.enable = lib.mkForce false;
  jovian.steamos.enableBluetoothConfig = true;
  jovian.decky-loader.enable = true;
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

  # Ensure we're using the BLEEDING EDGE version of GE Proton!
  programs.steam.extraCompatPackages = [
    pkgs.bleeding.proton-ge-bin
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

  # Prevent network disruption during system rebuilds
  systemd.services.NetworkManager.restartIfChanged = false;
  systemd.services.iwd.restartIfChanged = false;

  environment.systemPackages = with pkgs; [
    appimage-run
    brave
    glibcLocales
    cmake
    libdrm
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

  services.openssh.openFirewall = true;
  services.fail2ban.enable = true;

  # Homelab Beszel monitoring - filesystems and GPU auto-detected
  # services.homelab-beszel-agent = { };

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
