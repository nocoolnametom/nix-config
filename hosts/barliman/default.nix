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
    inputs.nix-amd-ai.nixosModules.default

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
    "hosts/common/optional/services/agent-worker.nix" # Low-privilege user for the coding agent's shell (PLAN.md)
    "hosts/common/optional/services/flatpak.nix"
    "hosts/common/optional/services/ollama.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/open-webui.nix"
    "hosts/common/optional/services/podman.nix"
    "hosts/common/optional/services/systemd-failure-pushover.nix"
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

  # barliman's Ollama lists these models under "_" names (my-sd-models'
  # machineLLMs/barliman.nix); the original names are removed after copying
  programs.image-prompt-loop.captionModel = "_llama-joycaption-beta-one-hf-llava";
  programs.image-prompt-loop.criticModel = "_qwen3-vl";

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
  # nix-amd-ai pins a different whisper-cpp than this nixpkgs ffmpeg-full expects
  # for --enable-whisper. Disable that ffmpeg feature locally so unrelated
  # packages (like open-webui) keep building while Lemonade is evaluated.
  nixpkgs.overlays = [
    (final: prev: {
      ffmpeg-full = prev.ffmpeg-full.override { withWhisper = false; };
    })
  ];

  # Open-WebUI is a web-frontend for chatting with ollama
  services.open-webui.package = pkgs.open-webui;
  # bleeding (nixpkgs master) since 2026-10-12: _qwen3.8's manifest asks for
  # the "qwen3.8" renderer, which Ollama 0.32.3 - the default channel's
  # version (nixos-26.05) - doesn't have, so it answers every request with
  # HTTP 500 "unknown renderer". The renderer exists by 0.34.4, so
  # pkgs.unstable.ollama-rocm (0.40.0 then) would also do. Go back to
  # pkgs.ollama-rocm once 26.05 ships 0.34.4 or newer.
  services.ollama.package = pkgs.bleeding.ollama-rocm;
  # Keep all local AI payloads under the same root, but still use separate per-
  # backend directories so Ollama and Lemonade do not try to share the same
  # runtime metadata/index tree. This avoids double-writing the same model data
  # while still keeping the storage layout coherent and easy to inspect.
  services.ollama.models = "/var/lib/ai-models/ollama";
  # Removed 2026-10-06 as no-ops: OLLAMA_LLAMA_GPU_LAYERS (not an Ollama
  # variable; Ollama already offloads every layer that fits), OLLAMA_GPU_OVERHEAD="1"
  # (1 byte, same as the default), HCC_AMDGPU_TARGET (a build-time setting), and
  # serviceConfig.UnsetEnvironment (discarded by the lib.mkForce in ollama.nix).
  services.ollama.environmentVariables.LD_LIBRARY_PATH = "/run/current-system/sw/lib";
  services.ollama.rocmOverrideGfx = "11.5.1";
  systemd.tmpfiles.rules = [
    "d '/var/lib/ai-models' 0755 root root - -"
    "d '/var/lib/ai-models/ollama' 0777 root root - -"
    "d '/var/lib/ai-models/lemonade' 0777 root root - -"
  ];

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

  # Evaluate Lemonade on Strix Halo alongside Ollama. Keep this GPU-only first
  # (ROCm + Vulkan) to avoid introducing NPU/FLM-specific complexity up front.
  hardware.amd-npu = {
    enable = true;
    gpuTarget = "gfx1151";
    enableNPU = false;
    enableFastFlowLM = false;
    enableLemonade = true;
    enableROCm = true;
    enableVulkan = true;
    enableImageGen = true;

    lemonade = {
      user = configVars.username;
      autoStart = true;
      # Listen on LAN interfaces; firewall rules below keep it private.
      host = "0.0.0.0";
      # Keep Lemonade under the shared model root so it sits beside Ollama's cache,
      # but still keeps its own runtime metadata/index tree instead of sharing a
      # single model directory between two unrelated backends.
      cacheDir = "/var/lib/ai-models/lemonade";
      settings = {
        max_loaded_models = 2;
        auto_evict = true;
      };
      # Machine-specific model list is tracked in my-sd-models so the same
      # declarative naming pattern used for Ollama applies here too. Older
      # my-sd-models revisions don't have the Lemonade registry yet, so fall back
      # to an empty list rather than crashing the host evaluation.
      models =
        let
          machineLemonadeModels =
            if builtins.hasAttr "machineLemonadeModels" pkgs.my-sd-models then
              pkgs.my-sd-models.machineLemonadeModels
            else
              { };
        in
        lib.attrByPath [ config.networking.hostName ] [ ] machineLemonadeModels;
      pruneUnlistedModels = false;
      # Required for browser UI/API access from other machines.
      allowedOrigins = [
        "http://${configVars.networking.subnets.barliman.ip}:${toString configVars.networking.ports.tcp.lemonade}"
        "http://${configVars.networking.subnets.barliman.name}.${configVars.homeLanDomain}:${toString configVars.networking.ports.tcp.lemonade}"
      ];
    };
  };

  # Upstream nix-amd-ai cache to avoid expensive local backend rebuilds.
  nix.settings = {
    substituters = lib.mkAfter [ "https://nix-amd-ai.cachix.org" ];
    trusted-substituters = lib.mkAfter [ "https://nix-amd-ai.cachix.org" ];
    trusted-public-keys =
      lib.mkAfter [ "nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ=" ];
  };

  # The coder model as the unattended worker uses it (PLAN.md, T4). Same
  # weights; two settings differ:
  #  - num_predict: the base model has no output cap, so one reply could run
  #    to the 196K context. In T4 (2026-10-12) a reply generated ~52,800
  #    tokens for 30 min (most likely a looping tool call) before a request
  #    timeout ended it. 16384 bounds that at ~6 min at barliman's ~46 tok/s,
  #    far above any real reply seen so far.
  #  - top_p: the GGUF's own default is 0.95; requests ran at 1.0.
  # Context size stays at the global value: T2's prompts reached ~70K.
  services.ollama.modelVariants."_qwen3-coder-next-worker" = {
    from = "_qwen3-coder-next";
    parameters = {
      num_predict = 16384;
      top_p = "0.95"; # a string: Nix would print the float as 0.950000
    };
  };

  # The reasoning model as the worker uses it, and the worker's model since
  # T2 runs 3-4 (2026-10-12): the only model to fix T2, and the only one
  # that followed the worker's SOUL.md. Its own sampling defaults (top_p
  # 0.95, top_k 20) are already right; only an output cap is added, larger
  # than the coder's because the reasoning counts too. The longest reply in
  # those runs was ~7K tokens; 32768 bounds a loop at ~12 min.
  services.ollama.modelVariants."_qwen3.8-worker" = {
    from = "_qwen3.8";
    parameters.num_predict = 32768;
  };

  # The Hermes "worker" profile logs in as agent-worker with this key. It is
  # kept out of hosts/common/users/<user>/keys on purpose: every file there
  # becomes a login key for the main user on every host.
  services.agent-worker.dispatcherKeys =
    let
      keyFile = configLib.relativeToRoot "hosts/common/users/${configVars.username}/agent-worker-keys/barliman.pub";
    in
    lib.optional (builtins.pathExists keyFile) (builtins.readFile keyFile);
  # The harness boots changed hosts as throwaway VMs to check them (PLAN.md,
  # Phase 2).
  services.agent-worker.vmTests.enable = true;

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
    # Hermes runs as a home-manager user service (home/tdoggett/barliman.nix),
    # and home-manager cannot touch the system firewall, so its two ports have
    # to be opened here: the gateway's bearer-key API and the dashboard that
    # estel's Caddy proxies.
    firewall.allowedTCPPorts = [
      configVars.networking.ports.tcp.hermes
      configVars.networking.ports.tcp.hermeswebui
      configVars.networking.ports.tcp.lemonade
    ];
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
