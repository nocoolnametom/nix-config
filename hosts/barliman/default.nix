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
    "hosts/common/optional/services/flatpak.nix"
    "hosts/common/optional/services/ollama.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/open-webui.nix"
    "hosts/common/optional/services/podman.nix"
    "hosts/common/optional/services/systemd-failure-pushover.nix"
    "hosts/common/optional/services/work-block.nix"
    "hosts/common/optional/amd-unified-memory.nix" # GPU memory limit (option set below)
    "hosts/common/optional/amdgpu_top.nix"
    "hosts/common/optional/cross-compiling.nix"
    "hosts/common/optional/nvtop.nix"
    "hosts/common/optional/bluetooth.nix"
    "hosts/common/optional/foreign-binaries.nix"
    "hosts/common/optional/llama-cpp.nix" # llama.cpp CLI tools (Vulkan)

    #################### Users to Create ####################
    # "home/${configVars.username}/persistence/barliman.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  # Native OIDC login through Kanidm (Authentik retires with cirdan).
  services.ssoProvider.openwebui = "kanidm-oidc";

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
  services.open-webui.package = pkgs.open-webui;
  services.ollama.package = pkgs.ollama-rocm;
  services.ollama.models = "/var/lib/ai-models/ollama";
  # Removed 2026-10-06 as no-ops: OLLAMA_LLAMA_GPU_LAYERS (not an Ollama
  # variable; Ollama already offloads every layer that fits), OLLAMA_GPU_OVERHEAD="1"
  # (1 byte, same as the default), HCC_AMDGPU_TARGET (a build-time setting), and
  # serviceConfig.UnsetEnvironment (discarded by the lib.mkForce in ollama.nix).
  services.ollama.environmentVariables.LD_LIBRARY_PATH = "/run/current-system/sw/lib";
  services.ollama.rocmOverrideGfx = "11.5.1";

  # Let the iGPU borrow most of system RAM. ONLY enable this together with
  # setting the BIOS iGPU memory (UMA frame buffer) to its minimum - see
  # hosts/common/optional/amd-unified-memory.nix for the reasoning.
  hardware.amdUnifiedMemory.gpuMemoryGiB = 52;

  # Bluetooth - Framework Desktop extras (base settings from bluetooth.nix)
  hardware.bluetooth.settings.General.Experimental = true;
  hardware.bluetooth.settings.Policy.AutoEnable = true;

  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "barliman";
    networkmanager.enable = true;
    # iwd backend caused "Too many open files" failures at early boot, leaving
    # the machine unconnected after a cold start. wpa_supplicant is more
    # reliable here since barliman is a fixed desktop with no power-mgmt needs.
    # networkmanager.wifi.backend = "iwd";
    enableIPv6 = true;
    firewall.enable = true;
    firewall.allowPing = true;
  };

  # Prevent network disruption during system rebuilds
  systemd.services.NetworkManager.restartIfChanged = false;

  environment.systemPackages = with pkgs; [
    appimage-run
    glibcLocales
    cmake
    libdrm
    gnumake
    nodejs
    p7zip
    samba
    screen
    unrar
    unzip
    neovim
    wget
  ];

  services.openssh.openFirewall = true;
  services.fail2ban.enable = true;

  # Homelab Beszel monitoring - filesystems and GPU auto-detected
  # services.homelab-beszel-agent = { };

  system.stateVersion = "26.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
