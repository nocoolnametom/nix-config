###############################################################################
#
#  Smeagol - Desktop
#  NixOS running on Personal AMD Desktop Machine - Dual Booting
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
    ./hardware-configuration.nix # Note that this only describes WSL stuff!

    ########################## Hardware Modules ###############################
    # No hardware to define!

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
    "hosts/common/optional/services/comfyui/default.nix"
    "hosts/common/optional/services/docker.nix"
    "hosts/common/optional/services/docker/invokeai.nix"
    "hosts/common/optional/services/flatpak.nix"
    "hosts/common/optional/services/ollama.nix"
    "hosts/common/optional/services/open-webui.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/pipewire.nix" # audio
    "hosts/common/optional/services/printing.nix"
    "hosts/common/optional/services/stashapp.nix"
    "hosts/common/optional/services/wivrn.nix"
    "hosts/common/optional/cross-compiling.nix"
    "hosts/common/optional/direnv.nix"
    "hosts/common/optional/jovian.nix"
    "hosts/common/optional/nvidia.nix"
    "hosts/common/optional/steam.nix"

    #################### Users to Create ####################
    # "home/${configVars.username}/persistence/smeagol.nix"
    "hosts/common/users/${configVars.username}"

    #
    "hosts/smeagol/logindhelper.nix"
  ]);

  # NzbGet Server - Current module is very bert-centric
  services.nzbget.enable = true;
  systemd.services.nzbget.path = with pkgs; [
    unrar
    unzip
    xz
    bzip2
    gnutar
    p7zip
    (pkgs.python3.withPackages (
      p: with p; [
        requests
        pandas
        configparser
      ]
    ))
    ffmpeg
  ];
  users.users."${configVars.username}".extraGroups = [
    config.services.stashapp.group
  ];
  users.users.nzbget.extraGroups = [
    config.services.stashapp.group
  ];
  users.users.stashapp.extraGroups = [
    config.services.nzbget.group
  ];
  systemd.tmpfiles.rules = [
    "d ${config.users.users.stashapp.home} 775 ${config.services.stashapp.user} ${config.services.stashapp.group} - -"
    "d ${config.users.users.stashapp.home}/data/data.dat/av1 777 ${config.services.stashapp.user} ${config.services.stashapp.group} - -"
  ];
  services.stashapp.vr-helper.enable = true;
  services.stashapp.vr-helper.stash-host = "http://${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.stash}";
  sops.secrets = {
    "smeagol-stashapp-api-key" = { };
  };
  sops.templates."stash-vr.conf".content = ''
    STASH_API_KEY=${config.sops.placeholder."smeagol-stashapp-api-key"}
  '';
  services.stashapp.vr-helper.apiEnvironmentVariableFile = config.sops.templates."stash-vr.conf".path;

  # Automatically transcode VR files
  services.nzbget-to-management.enable = true;
  services.nzbget-to-management.downloadedDestDir = "/var/lib/stashapp/data/data.dat/vr";
  services.nzbget-to-management.unpackingDirName = "_unpack";
  services.nzbget-to-management.transcodingTempDir = "/var/lib/stashapp/data/data.dat/transcoding";
  services.nzbget-to-management.finishedVideoDir = "/var/lib/stashapp/data/data.dat/av1";
  services.nzbget-to-management.handbrakePresetJsonFilePath = "/var/lib/stashapp/data/data.dat/MyVRAV1s.json";
  services.nzbget-to-management.handbrakePreset = "MyVRAV1s";

  # Remote video conversion from stash server
  services.stash-video-conversion.enable = true;
  services.stash-video-conversion.graphqlEndpoint = "http://${configVars.networking.subnets.durin.ip}:${builtins.toString configVars.networking.ports.tcp.stash}/graphql";
  services.stash-video-conversion.remoteHost = configVars.networking.subnets.durin.ip;
  services.stash-video-conversion.remoteUser = configVars.username;
  services.stash-video-conversion.remoteUploadDir = "/arkenstone/stash/library/unorganized/_staging/finished";
  services.stash-video-conversion.incomingDir = "/var/lib/stash-video-conversion/incoming";
  services.stash-video-conversion.transcodingDir = "/var/lib/stash-video-conversion/transcoding";
  services.stash-video-conversion.finishedDir = "/var/lib/stash-video-conversion/finished";
  services.stash-video-conversion.handbrakePresetJsonFilePath = "/var/lib/stash-video-conversion/MyVRAV1s.json";
  services.stash-video-conversion.handbrakePreset = "MyVRAV1s";
  services.stash-video-conversion.perPageLimit = 50;

  # Secrets configuration
  sops.secrets."bert-stashapp-api-key" = { };
  sops.secrets."stash-video-rsync-key" = {
    key = "ssh/personal/root_only/stash-conversion"; # Passwordless key for automation
    mode = "0600";
    owner = config.services.stash-video-conversion.user;
    group = config.services.stash-video-conversion.group;
  };
  sops.templates."stash-video-conversion.env".content = ''
    API_KEY=${config.sops.placeholder."bert-stashapp-api-key"}
    SSH_KEY_PATH=${config.sops.secrets."stash-video-rsync-key".path}
  '';
  services.stash-video-conversion.environmentFile =
    config.sops.templates."stash-video-conversion.env".path;

  # ComfyUI Configuration
  # Use Docker backend instead of native
  services.comfyui.useDocker = true;
  services.comfyui.comfyuimini.enable = true;

  # Docker-specific configuration
  services.comfyui.docker.workingDir = "/var/lib/comfyui-docker";
  services.comfyui.docker.environment = {
    CLI_ARGS = "--preview-method auto";
    DIRECT_ADDRESS = "${configVars.networking.subnets.smeagol.ip}:${builtins.toString config.services.comfyui.docker.port}";
    DIRECT_ADDRESS_GET_WAN = "false";
    WEB_ENABLE_AUTH = "false";
  };

  # Declaratively install custom nodes
  # These will be automatically installed on boot if not present
  # You can still manually install more via ComfyUI Manager!
  services.comfyui.docker.customNodes = [
    # Essential manager and video nodes
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/kijai/ComfyUI-HunyuanVideoWrapper" # Wanx 2.1 / Hunyuan Video
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"

    # Nodes from my-sd-models (previously managed via Nix, now Docker auto-install)
    "https://github.com/Acly/comfyui-inpaint-nodes" # Inpainting nodes
    "https://github.com/agilly1989/ComfyUI_agilly1989_motorway" # Motorway nodes
    "https://github.com/audioscavenger/save-image-extended-comfyui" # Extended save options
    "https://github.com/chrisfreilich/virtuoso-nodes" # Virtuoso nodes
    "https://github.com/city96/ComfyUI-GGUF" # GGUF model support
    "https://github.com/cubiq/ComfyUI_essentials" # Essential utilities
    "https://github.com/EllangoK/ComfyUI-post-processing-nodes" # Post-processing
    "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation" # Frame interpolation
    "https://github.com/kijai/ComfyUI-KJNodes" # KJ Nodes
    "https://github.com/kijai/ComfyUI-segment-anything-2" # Segment Anything 2
    "https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch" # Crop and stitch
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack" # Impact Pack
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts" # Custom scripts
    "https://github.com/rgthree/rgthree-comfy" # rgthree utilities
    "https://github.com/sipherxyz/comfyui-art-venture" # Art Venture
    "https://github.com/space-nuko/ComfyUI-OpenPose-Editor" # OpenPose editor
    "https://github.com/Tropfchen/ComfyUI-yaResolutionSelector" # Resolution selector
    "https://github.com/WASasquatch/was-node-suite-comfyui" # WAS Node Suite

    # Optional animation nodes:
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"
  ];

  # Declaratively download workflow files
  # Key = filename to save as, Value = URL to download from
  # You can still manually create/import workflows via ComfyUI UI!
  services.comfyui.docker.workflows = {
    # Hunyuan Video workflows (uncomment to enable):
    # Note: These require the Hunyuan models to be installed first!

    # Example workflows from various sources:
    # "hunyuan-text2video-basic.json" = "https://civitai.com/api/download/models/1375389";  # CivitAI: ComfyTinker's basic T2V
    # "hunyuan-image2video-fast.json" = "https://civitai.com/api/download/models/1328592";  # CivitAI: Fast I2V workflow

    # Alternative sources for workflows:
    # - OpenArt.ai: Search "hunyuan video" and export workflow as JSON
    # - GitHub: Check kijai/ComfyUI-HunyuanVideoWrapper for example workflows
    # - ComfyUI Wiki: docs.comfy.org has tutorial workflows
    # - Your own: Create in UI and export via "Save (API Format)"

    # To add custom workflows:
    # 1. Find or create a workflow
    # 2. If from web, get direct download URL or API endpoint
    # 3. Add here with descriptive filename
    # 4. Your CivitAI and HuggingFace keys will be used automatically
  };

  # Declaratively download model files (happens after boot, doesn't block)
  # Models are downloaded by a separate systemd service and ComfyUI restarts when done
  # Only downloads if model doesn't already exist - safe to rebuild!
  # Your HuggingFace and CivitAI API keys are automatically used for authentication!
  services.comfyui.docker.models = [
    # Hunyuan Video models (WARNING: Very large files, 20GB+ total!)
    # Uncomment to enable automatic download:

    # Main transformer model (~13GB) - FP8 quantized version for better performance
    # {
    #   url = "https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_720_cfgdistill_fp8_e4m3fn.safetensors";
    #   destination = "diffusion_models/hunyuan_video_720_cfgdistill_fp8_e4m3fn.safetensors";
    # }

    # Text encoder - LLAMA model (~5GB)
    # {
    #   url = "https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/llava_llama3_fp8_scaled.safetensors";
    #   destination = "text_encoders/llava_llama3_fp8_scaled.safetensors";
    # }

    # CLIP text encoder (~1.4GB)
    # {
    #   url = "https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/clip_l.safetensors";
    #   destination = "text_encoders/clip_l.safetensors";
    # }

    # VAE decoder (~1GB)
    # {
    #   url = "https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_vae_bf16.safetensors";
    #   destination = "vae/hunyuan_video_vae_bf16.safetensors";
    # }

    # Your API keys from sops-nix are automatically used:
    # - HuggingFace: For gated/private models from huggingface.co
    # - CivitAI: For premium/early-access models from civitai.com

    # You can also add models from CivitAI:
    # {
    #   url = "https://civitai.com/api/download/models/MODEL_ID";
    #   destination = "checkpoints/model_name.safetensors";
    # }

    # Note: First boot after uncommenting these will take a LONG time
    # Watch progress with: journalctl -fu comfyui-download-models.service
    # Models persist across reboots, so this only happens once!
  ];

  # If using native instead: set useDocker = false and configure:
  # services.comfyui.symlinkPaths = {
  #   checkpoints = "/var/lib/stable-diffusion/models/linked/checkpoints";
  #   loras = "/var/lib/stable-diffusion/models/linked/loras";
  # };
  # services.comfyui.models = lib.mkForce []; # Use before sops-nix secrets are loaded

  # Bluetooth
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

  # InvokeAI stuff
  services.invokeai.workingDir = "/var/lib/stable-diffusion";
  services.invokeai.settings.enable_partial_loading = true;
  services.invokeai.settings.pytorch_cuda_alloc_conf = "backend:cudaMallocAsync";
  services.invokeai.settings.max_cache_ram_gb = 40.0;
  services.invokeai.settings.device_working_mem_gb = 3.0;
  sops.templates."invokeai-secrets.env" = {
    content = ''
      INVOKEAI_REMOTE_API_TOKENS=${
        builtins.toJSON [
          {
            url_regex = "civitai.com";
            token = config.sops.placeholder."civitai_key";
          }
          {
            url_regex = "huggingface";
            token = config.sops.placeholder."huggingface_key";
          }
        ]
      }
    '';
    mode = "777";
  };
  services.invokeai.additionalEnvironmentFile = config.sops.templates."invokeai-secrets.env".path;

  # Some Jovian stuff just for smeagol
  jovian.devices.steamdeck.enable = lib.mkForce false;
  jovian.hardware.has.amd.gpu = lib.mkForce false;
  systemd.targets.suspend.enable = lib.mkForce false;

  # The networking hostname is used in a lot of places, such as secret retrieval!
  networking = {
    hostName = "smeagol";
    networkmanager.enable = true;
    enableIPv6 = true;
    firewall.enable = false;
  };

  environment.systemPackages = with pkgs; [
    appimage-run
    brave
    claude-code
    glibcLocales
    gparted
    gnumake
    nodejs
    p7zip
    yt-dlp
    samba
    screen
    unrar
    unzip
    vim
    wget
    libation
    google-chrome
  ];

  # Run AppImages directly
  programs.appimage.binfmt = true;

  # Security
  security.sudo.wheelNeedsPassword = false;

  # Fixes VSCode remote
  programs.nix-ld.enable = true;

  # Build documentation
  documentation.nixos.enable = false;

  system.stateVersion = "25.05";

  users.users.root.initialHashedPassword = "$y$j9T$kJlllzou9ACSf/q6LFgPi.$A49llCkktVbbfOHVvdjSRnPD27.jg4xSYaLlG5p9t5A";
}
