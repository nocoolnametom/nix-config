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
    "hosts/common/optional/services/hermes-agent.nix" # Hermes Agent API for Conduit
    "hosts/common/optional/services/ollama.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/open-webui.nix"
    "hosts/common/optional/services/podman.nix"
    "hosts/common/optional/services/systemd-failure-pushover.nix"
    "hosts/common/optional/services/work-block.nix"
    "hosts/common/optional/home-wifi.nix" # Declarative home Wi-Fi profile (secrets from nix-secrets)
    "hosts/common/optional/wifi-watchdog.nix" # Reconnect Wi-Fi (no Ethernet here); options set below
    "hosts/common/optional/amd-unified-memory.nix" # GPU memory limit (option set below)
    "hosts/common/optional/amdgpu_top.nix"
    "hosts/common/optional/cross-compiling.nix"
    "hosts/common/optional/nvtop.nix"
    "hosts/common/optional/bluetooth.nix"
    "hosts/common/optional/foreign-binaries.nix"
    "hosts/common/optional/llama-cpp.nix" # llama.cpp CLI tools (Vulkan)
    "hosts/common/optional/llmfit.nix" # LLM fit estimates, told the real GPU limit
    "hosts/common/optional/image-prompt-loop.nix" # ComfyUI/InvokeAI prompt refinement with vision models

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
    "hermes-agent"
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
  hardware.amdUnifiedMemory.systemMemoryGiB = 62; # 64 GB minus the 0.5 GB BIOS carve-out

  # Two slots per loaded model, so Open WebUI's background requests (titles,
  # tags, follow-up suggestions) run in their own slot. They don't queue behind
  # the chat or overwrite its cached history, which would force the next prompt
  # to re-read the whole conversation, which takes minutes at long context
  # (~300 tokens/s). It also lets an agent and a chat use the same model at
  # once. Costs one extra KV cache per model, the full context size each: at
  # 192K, qwen3:30b-a3b needs ~37 GiB with two slots versus ~27 GiB with one.
  services.ollama.environmentVariables.OLLAMA_NUM_PARALLEL = "2";

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

  # barliman has no Ethernet cable, so a dropped Wi-Fi link means it is
  # unreachable. Its MediaTek MT7925 card is known to drop and stay down on
  # Linux; turn off its PCIe power saving and let the watchdog recover it.
  networking.wifiWatchdog = {
    driverModule = "mt7925e";
    disableDriverAspm = true;
    # With no country set, the card keeps trying the router's 6 GHz access
    # points, fails, and resets its firmware (hundreds of times per boot)
    regulatoryDomain = "US";
    # This box serves externally reachable UIs, so recover sooner: two
    # reconnect tries (checks 2 and 3), then reload the driver at check 4
    driverReloadAfter = 4;
  };

  # Stay on 5 GHz. Even with the country set, every connection roamed to
  # 6 GHz and the first login there went unanswered (up to minutes offline).
  # An LLM box doesn't need 6 GHz bandwidth; staying up matters more.
  networking.homeWifi.band = "a";

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
