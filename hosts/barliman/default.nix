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
  # Models not in Lemonade's built-in registry, registered by Hugging Face
  # checkpoint (lemond exposes them as user.<name>).
  machineLemonadeCustomModels =
    if builtins.isAttrs machineLemonadeCatalog then machineLemonadeCatalog.customModels or { } else { };
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

  # Caption and critic models come from my-sd-models' machinePrimaryLLMs/barliman.nix.
  programs.image-prompt-loop.captionModel = pkgs.my-sd-models.machinePrimaryLLMs.barliman.caption;
  programs.image-prompt-loop.criticModel = pkgs.my-sd-models.machinePrimaryLLMs.barliman.critic;

  # Native OIDC login through Kanidm (Authentik retires with cirdan).
  services.ssoProvider.openwebui = "kanidm-oidc";
  services.obscuraWebLoader.enable = true;

  # Send alerts on systemd service failures
  services.systemd-failure-alert.additional-services = [
    "open-webui"
    "lemond"
    "lemonade-extra-snapshots"
    "strata-prepare"
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

  # Open-WebUI is a web-frontend for chatting with Lemonade.
  services.open-webui.package = pkgs.open-webui;
  # Keep all local AI payloads under one root; Lemonade keeps its own tree below it.
  systemd.tmpfiles.rules = [
    "d '/var/lib/ai-models' 0755 root root - -"
    "d '/var/lib/ai-models/lemonade' 0777 root root - -"
  ];

  # Let the iGPU borrow most of system RAM. ONLY enable this together with
  # setting the BIOS iGPU memory (UMA frame buffer) to its minimum - see
  # hosts/common/optional/amd-unified-memory.nix for the reasoning.
  hardware.amdUnifiedMemory.gpuMemoryGiB = 52;
  hardware.amdUnifiedMemory.systemMemoryGiB = 62; # 64 GB minus the 0.5 GB BIOS carve-out

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
      # Keep Lemonade under the shared model root, with its own runtime metadata
      # and index tree.
      cacheDir = lemonadeCacheDir;
      # No Tauri desktop app: barliman is headless; avoids the Rust+npm build.
      desktopApp.enable = false;
      settings = {
        max_loaded_models = 3;
        auto_evict = true;
        auto_evict_threshold_pct = 0.90; # start evicting at 90% VRAM pressure
      };
      # Machine-specific model list is tracked in my-sd-models. Older
      # my-sd-models revisions don't have the Lemonade registry yet, so fall back
      # to an empty list rather than crashing the host evaluation.
      models = machineLemonadeModels;
      customModels = machineLemonadeCustomModels;
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
  # lemond reads LEMONADE_ADMIN_API_KEY (not LEMONADE_ADMIN_KEY); the wrong name
  # is silently ignored and /internal/* then accepts the regular key.
  sops.templates."lemonade.env" = {
    content = ''
      LEMONADE_API_KEY=${config.sops.placeholder."homelab/lemonade/api-key"}
      LEMONADE_ADMIN_API_KEY=${config.sops.placeholder."homelab/lemonade/admin-key"}
    '';
    # The env file is read at process start, so rotating either key must restart lemond.
    restartUnits = [ "lemond.service" ];
  };
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
      # Stay "active" after a successful run. strata-prepare Requires this unit,
      # and without this a finished oneshot is re-run every time strata-prepare
      # pulls it in (OnSuccess above), until StartLimitBurst is hit.
      RemainAfterExit = true;
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

  # The Hermes worker's model is machinePrimaryLLMs.barliman.worker (Qwen3.6
  # 35B-A3B on Lemonade's llama.cpp recipe). Its output cap is llama-server's
  # --n-predict as a server default: Hermes leaves max_tokens unset, so the
  # default applies and bounds a looping run. 32768 is the cap the Ollama
  # worker variant used; the longest reply seen was ~7K tokens. Strata
  # (Qwen3.8-Flash-Next) can't take this flag through lemond, so it isn't used.
  hardware.amd-npu.lemonade.recipeOptions."builtin.Qwen3.6-35B-A3B-MTP-GGUF" = {
    llamacpp_args = "--n-predict 32768";
    ctx_size = 131072;
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
