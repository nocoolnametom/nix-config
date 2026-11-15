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
let
  # Lemonade and the auxiliary HF downloader share this cache root. Keep this
  # aligned with the cacheDir passed to the Lemonade service below.
  lemonadeCacheDir = "/var/lib/ai-models/lemonade";
  lemonadeHfCacheDir = "${lemonadeCacheDir}/hf/hub";
  machineLemonadeCatalogs = pkgs.my-sd-models.machineLemonadeModels or { };
  machineLemonadeCatalog = lib.attrByPath [ config.networking.hostName ] [ ] machineLemonadeCatalogs;
  machineLemonadeModels =
    if builtins.isAttrs machineLemonadeCatalog then
      machineLemonadeCatalog.models or [ ]
    else if builtins.isList machineLemonadeCatalog then
      machineLemonadeCatalog
    else
      [ ];
  # These downloads are separate from Lemonade's model IDs: they are pinned
  # snapshots consumed directly by services such as Strata.
  machineLemonadeSnapshots =
    if builtins.isAttrs machineLemonadeCatalog then machineLemonadeCatalog.snapshots or [ ] else [ ];
  huggingfaceHub = pkgs.python3Packages."huggingface-hub";
  snapshotDownloadCommand =
    snapshot:
    let
      # Older locked my-sd-models revisions predate these transfer fields.
      # Until that input is updated, retain hf's defaults for those records.
      transport = snapshot.transport or "xet";
      maxWorkers = snapshot.maxWorkers or 8;
      # Hugging Face Hub uses Xet automatically when hf-xet is installed.
      # For snapshots marked `http`, disable that backend for this CLI process.
      transportEnvironment = lib.optionalString (transport == "http") "HF_HUB_DISABLE_XET=1 ";
    in
    "${transportEnvironment}hf download ${
      lib.escapeShellArgs (
        [
          snapshot.repo
          "--revision"
          snapshot.revision
          "--cache-dir"
          lemonadeHfCacheDir
          "--max-workers"
          (toString maxWorkers)
        ]
        ++ lib.concatMap (pattern: [
          "--include"
          pattern
        ]) snapshot.include
      )
    }";
  snapshotDownloadCommands =
    lib.concatMapStringsSep "\n" snapshotDownloadCommand
      machineLemonadeSnapshots;
in
{
  imports = [
    ######################## Every Host Needs This ############################
    ./hardware-configuration.nix

    ########################## Hardware Modules ###############################
    inputs.hardware.nixosModules.framework-desktop-amd-ai-max-300-series
    inputs.nix-amd-ai.nixosModules.default

    ########################### Impermanence ##################################
    ./persistence.nix
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
    "hosts/common/optional/services/ollama.nix"
    "hosts/common/optional/services/comin.nix" # follows this repo's main branch from GitHub and switches to it
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/open-webui.nix"
    "hosts/common/optional/services/obscura-web-loader.nix"
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
  services.obscuraWebLoader.enable = true;

  # Send alerts on systemd service failures
  services.systemd-failure-alert.additional-services = [
    "ollama"
    "open-webui"
    "lemond"
    "lemonade-extra-snapshots"
    "strata-prepare"
    "strata-server"
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
  services.ollama.environmentVariables.OLLAMA_NUM_PARALLEL = "3";

  # Full AMD AI stack on Strix Halo: ROCm + Vulkan + XDNA-2 NPU + FLM +
  # vLLM ROCm + Strata (Qwen3.8-Flash-Next with custom attention). All backends
  # that nix-amd-ai exposes for gfx1151 are wired; lemond routes each model to
  # the backend it was trained/quantised for.
  hardware.amd-npu = {
    enable = true;
    gpuTarget = "gfx1151";
    enableNPU = true; # XDNA-2 NPU: kernel module, XRT, udev, memlock
    enableFastFlowLM = true; # FastFlowLM NPU inference runtime
    enableLemonade = true;
    enableROCm = true;
    enableVulkan = true;
    enableImageGen = true; # sd-cpp: cpu / rocm / vulkan backends
    enableVllm = true; # vLLM ROCm (gfx1151 prebuilt from lemonade-sdk)

    # Strata: dedicated Qwen3.8-Flash-Next server optimised for Strix Halo.
    # strata.prepare auto-runs to pre-pack the model; defaults (UD-IQ4_XS quant,
    # 128K context, /var/lib/strata pack+mtp paths) are fine for this box.
    strata.enable = true;

    lemonade = {
      user = configVars.username;
      autoStart = true;
      # Listen on LAN interfaces; firewall rules below keep it private.
      host = "0.0.0.0";
      # Keep Lemonade under the shared model root so it sits beside Ollama's cache,
      # but still keeps its own runtime metadata/index tree instead of sharing a
      # single model directory between two unrelated backends.
      cacheDir = lemonadeCacheDir;
      # No Tauri desktop app: barliman is headless; avoids the Rust+npm build.
      desktopApp.enable = false;
      settings = {
        max_loaded_models = 3;
        auto_evict = true;
        auto_evict_threshold_pct = 0.90; # start evicting at 90% VRAM pressure
      };
      # Machine-specific model list is tracked in my-sd-models so the same
      # declarative naming pattern used for Ollama applies here too. Older
      # my-sd-models revisions don't have the Lemonade registry yet, so fall back
      # to an empty list rather than crashing the host evaluation.
      models = machineLemonadeModels;
      pruneUnlistedModels = false;
      # Required for browser UI/API access from other machines.
      allowedOrigins = [
        "http://${configVars.networking.subnets.barliman.ip}:${toString configVars.networking.ports.tcp.lemonade}"
        "http://${configVars.networking.subnets.barliman.name}.${configVars.homeLanDomain}:${toString configVars.networking.ports.tcp.lemonade}"
      ];
    };
  };

  # Lemonade API key. lemond reads LEMONADE_API_KEY and, once set, requires a
  # matching `Authorization: Bearer <key>` header on every /api/, /v1/, /v0/,
  # /mcp and /metrics route (lemonade request_middleware.cpp); an empty key
  # leaves them open. Clients that reach barliman's endpoint across the LAN
  # must send it; local clients can keep using a placeholder key until they are
  # updated to send the real one.
  #
  # The value reaches lemond through a rendered sops env file rather than the
  # unit's Environment= block: sops-nix substitutes config.sops.placeholder only
  # inside sops.templates, and systemd reads the file as root before dropping to
  # the tdoggett user, so the default 0400 root-owned file is still readable.
  sops.secrets."homelab/lemonade/api-key" = { };
  sops.secrets."homelab/lemonade/admin-key" = { };
  sops.templates."lemonade.env".content = ''
    LEMONADE_API_KEY=${config.sops.placeholder."homelab/lemonade/api-key"}
    LEMONADE_ADMIN_KEY=${config.sops.placeholder."homelab/lemonade/admin-key"}
  '';
  systemd.services.lemond.serviceConfig.EnvironmentFile = config.sops.templates."lemonade.env".path;

  # The model reconciler uses the Lemonade CLI, which reads its API key from the
  # environment. Give it only the regular key needed for /api/v1 requests.
  sops.templates."lemonade-model-sync.env".content = ''
    LEMONADE_API_KEY=${config.sops.placeholder."homelab/lemonade/api-key"}
  '';
  sops.templates."lemonade-model-sync.env".restartUnits = [ "lemond-models.service" ];
  systemd.services.lemond-models.serviceConfig.EnvironmentFile =
    config.sops.templates."lemonade-model-sync.env".path;

  # Lemonade cannot pull every backend's weights by its catalog model ID. Fetch
  # the pinned snapshots declared in machineLemonadeModels/<host>.nix directly
  # into the same HF cache used by Lemonade. Add future direct-download models
  # to that `snapshots` list; keep their repo, revision, and include patterns in
  # sync with the service that consumes their files. If a source is gated, add
  # its token through SOPS here rather than putting credentials in the catalog.
  systemd.services.lemonade-extra-snapshots = lib.mkIf (machineLemonadeSnapshots != [ ]) {
    description = "Download pinned Hugging Face snapshots required by host services";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ huggingfaceHub ];
    environment = {
      # Bound individual Hub HTTP/metadata requests; the outer systemd timeout
      # below also covers a stalled transfer implementation.
      HF_HUB_DOWNLOAD_TIMEOUT = "300";
      HF_HUB_ETAG_TIMEOUT = "60";
      HF_HUB_DISABLE_UPDATE_CHECK = "1";
    };
    unitConfig = {
      # A successful retry should also re-run Strata prep if its first attempt
      # failed because a previous download was incomplete.
      OnSuccess = [ "strata-prepare.service" ];
      StartLimitIntervalSec = "1d";
      StartLimitBurst = 3;
    };
    serviceConfig = {
      Type = "oneshot";
      User = configVars.username;
      # Large model snapshots can take hours, but must not wait forever. Failed
      # attempts resume from Hugging Face's .incomplete cache files.
      TimeoutStartSec = "4h";
      Restart = "on-failure";
      RestartSec = "5min";
    };
    script = ''
      set -euo pipefail
      ${snapshotDownloadCommands}
    '';
  };

  # Require the snapshot fetch to finish before strata-prepare checks its model
  # path and builds the pack/MTP runtime. A failed download should fail Strata
  # preparation visibly instead of racing it or silently using another revision.
  systemd.services.strata-prepare = lib.mkIf (machineLemonadeSnapshots != [ ]) {
    requires = [ "lemonade-extra-snapshots.service" ];
    after = [ "lemonade-extra-snapshots.service" ];
  };

  # Upstream nix-amd-ai cache to avoid expensive local backend rebuilds.
  nix.settings = {
    substituters = lib.mkAfter [ "https://nix-amd-ai.cachix.org" ];
    trusted-substituters = lib.mkAfter [ "https://nix-amd-ai.cachix.org" ];
    trusted-public-keys = lib.mkAfter [
      "nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ="
    ];
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
