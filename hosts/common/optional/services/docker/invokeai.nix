{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.invokeai;

  # Helper: convert arbitrary value to a string suitable for .env
  toEnvString =
    value:
    if isBool value then
      (if value then "true" else "false")
    else if isList value || isAttrs value then
      builtins.toJSON value
    else if value == null then
      "" # skip later
    else
      toString value;

  # Filter out unset/null values
  filteredSettings = filterAttrs (_: v: v != null && v != { }) cfg.settings;

  # Create a list of "INVOKEAI_KEY=value" lines
  envLines = mapAttrsToList (
    name: value: "INVOKEAI_${strings.toUpper name}=${toEnvString value}"
  ) filteredSettings;

  envFile = pkgs.writeText "invokeai.env" (concatStringsSep "\n" envLines);
in
{
  options.services.invokeai = with types; {
    enable = mkOption {
      type = bool;
      default = true;
      description = "Enable the InvokeAI service";
    };

    active = mkOption {
      type = bool;
      default = true;
      description = "Enable the InvokeAI service";
    };

    version = mkOption {
      type = str;
      example = "latest";
      default = "6.9.0";
      description = "Version of the InvokeAI container to use";
    };

    port = mkOption {
      type = int;
      default = 9090;
      description = "Port to access InvokeAI from";
    };

    openFirewall = mkOption {
      type = bool;
      default = false;
      description = "Open the firewall for the InvokeAI service";
    };

    workingDir = mkOption {
      type = str;
      default = "/var/lib/invokeai";
      description = "Working directory for InvokeAI data.";
    };

    modelsDir = mkOption {
      type = path;
      default = "${cfg.workingDir}/models";
      description = "Path to the models directory.";
    };

    downloadCacheDir = mkOption {
      type = path;
      default = "${cfg.workingDir}/downloads";
      description = "Path to the directory containing dynamically downloaded models.";
    };

    legacyConfDir = mkOption {
      type = path;
      default = "${cfg.workingDir}/configs";
      description = "Path to directory of legacy checkpoint config files.";
    };

    dbDir = mkOption {
      type = path;
      default = "${cfg.workingDir}/db";
      description = "Path to InvokeAI databases directory.";
    };

    outputsDir = mkOption {
      type = path;
      default = "${cfg.workingDir}/outputs";
      description = "Path to directory for outputs.";
    };

    customNodesDir = mkOption {
      type = path;
      default = "${cfg.workingDir}/custom_nodes";
      description = "Path to directory for custom nodes.";
    };

    stylePresetsDir = mkOption {
      type = path;
      default = "${cfg.workingDir}/style_presets";
      description = "Path to directory for style presets.";
    };

    workflowThumbnailsDir = mkOption {
      type = path;
      default = "${cfg.workingDir}/workflow_thumbnails";
      description = "Path to directory for workflow thumbnails.";
    };

    settings = mkOption {
      type = submodule {
        freeformType = attrsOf anything;
        options = {
          log_tokenization = mkOption {
            default = null;
            type = nullOr bool;
            description = "Enable logging of parsed prompt tokens.";
          };

          patchmatch = mkOption {
            default = null;
            type = nullOr bool;
            description = "Enable patchmatch inpaint code.";
          };

          log_handlers = mkOption {
            default = null;
            type = nullOr (listOf str);
            example = [ "console" ];
            description = "List of log handlers (console, file=, syslog=path|address:host:port, http=).";
          };

          log_format = mkOption {
            default = null;
            type = nullOr (enum [
              "plain"
              "color"
              "syslog"
              "legacy"
            ]);
            description = "Log format.";
          };

          log_level = mkOption {
            default = null;
            type = nullOr (enum [
              "debug"
              "info"
              "warning"
              "error"
              "critical"
            ]);
            description = "Emit logging messages at this level or higher.";
          };

          log_sql = mkOption {
            default = null;
            type = nullOr bool;
            description = "Log SQL queries (only if log_level=debug).";
          };

          log_level_network = mkOption {
            default = null;
            type = nullOr (enum [
              "debug"
              "info"
              "warning"
              "error"
              "critical"
            ]);
            example = "info";
            description = "Log level for network-related messages.";
          };

          use_memory_db = mkOption {
            default = null;
            type = nullOr bool;
            description = "Use in-memory database (useful for development).";
          };

          dev_reload = mkOption {
            default = null;
            type = nullOr bool;
            description = "Automatically reload when Python sources are changed.";
          };

          profile_graphs = mkOption {
            default = null;
            type = nullOr bool;
            description = "Enable graph profiling using cProfile.";
          };

          profile_prefix = mkOption {
            default = null;
            type = nullOr str;
            description = "Optional prefix for profile output files.";
          };

          profiles_dir = mkOption {
            default = null;
            type = nullOr path;
            example = "/var/lib/invokeai/profiles";
            description = "Path to profiles output directory.";
          };

          max_cache_ram_gb = mkOption {
            default = null;
            type = nullOr float;
            description = "Maximum CPU RAM for model caching (GB).";
          };

          max_cache_vram_gb = mkOption {
            default = null;
            type = nullOr float;
            description = "Maximum VRAM for model caching (GB).";
          };

          log_memory_usage = mkOption {
            default = null;
            type = nullOr bool;
            description = "Log memory snapshots before/after model cache operations.";
          };

          device_working_mem_gb = mkOption {
            default = null;
            type = nullOr float;
            description = "Working memory reserved on GPU (GB).";
          };

          enable_partial_loading = mkOption {
            default = null;
            type = nullOr bool;
            description = "Enable partial loading of models to reduce VRAM usage.";
          };

          keep_ram_copy_of_weights = mkOption {
            default = null;
            type = nullOr bool;
            description = "Keep RAM copy of weights to speed up model switching.";
          };

          pytorch_cuda_alloc_conf = mkOption {
            default = null;
            type = nullOr str;
            description = "Torch CUDA memory allocator configuration string (e.g., backend:cudaMallocAsync).";
          };

          precision = mkOption {
            default = null;
            type = nullOr (enum [
              "auto"
              "float16"
              "bfloat16"
              "float32"
            ]);
            description = "Floating point precision.";
          };

          sequential_guidance = mkOption {
            default = null;
            type = nullOr bool;
            description = "Compute guidance serially instead of in parallel.";
          };

          attention_type = mkOption {
            default = null;
            type = nullOr (enum [
              "auto"
              "normal"
              "xformers"
              "sliced"
              "torch-sdp"
            ]);
            description = "Attention implementation type.";
          };

          attention_slice_size = mkOption {
            default = null;
            type = nullOr (oneOf [
              int
              (enum [
                "auto"
                "balanced"
                "max"
              ])
            ]);
            description = "Slice size for sliced attention mode.";
          };

          force_tiled_decode = mkOption {
            default = null;
            type = nullOr bool;
            description = "Enable tiled VAE decode to reduce memory consumption.";
          };

          pil_compress_level = mkOption {
            default = null;
            type = nullOr int;
            description = "PNG compression level for PIL (0–9).";
          };

          max_queue_size = mkOption {
            default = null;
            type = nullOr int;
            description = "Maximum number of items in session queue.";
          };

          clear_queue_on_startup = mkOption {
            default = null;
            type = nullOr bool;
            description = "Clear session queue on startup.";
          };

          allow_nodes = mkOption {
            default = null;
            type = nullOr (listOf str);
            description = "List of nodes to allow ";
          };

          deny_nodes = mkOption {
            default = null;
            type = nullOr (listOf str);
            description = "List of nodes to deny";
          };

          node_cache_size = mkOption {
            default = null;
            type = nullOr int;
            description = "Number of cached nodes to keep in memory";
          };

          hashing_algorithm = mkOption {
            default = null;
            type = nullOr (enum [
              "blake3_multi"
              "blake3_single"
              "random"
              "md5"
              "sha1"
              "sha224"
              "sha256"
              "sha384"
              "sha512"
              "blake2b"
              "blake2s"
              "sha3_224"
              "sha3_256"
              "sha3_384"
              "sha3_512"
              "shake_128"
              "shake_256"
            ]);
            description = "Model hashing algorithm for model installs";
          };

          remote_api_tokens = mkOption {
            default = null;
            type = nullOr (listOf attrs);
            description = "List of regex/token pairs for authenticated model downloads";
          };

          allow_unknown_models = mkOption {
            default = null;
            type = nullOr bool;
            description = "Allow installation of unrecognized models";
          };
        };
      };

      default = { };
      example = literalExpression ''
        {
          host = "0.0.0.0";
          port = 9090;
          models_dir = "/srv/invokeai/models";
          precision = "float16";
          device = "cuda";
          remote_api_tokens = [
            { url_regex = "modelmarketplace"; token = "12345"; }
          ];
        }
      '';
      description = ''
        InvokeAI configuration options.
        These are converted into environment variables for the Docker/Arion service. 
        See <link xlink:href="https://invoke-ai.github.io/InvokeAI/configuration/#all-settings"/> for the upstream documentation.
      '';
    };

    envFile = mkOption {
      type = path;
      readOnly = true;
      default = pkgs.writeText "invokeai.env" (concatStringsSep "\n" envLines);
      description = "Generated environment file containing INVOKEAI_* variables.";
    };
  };

  config = mkIf cfg.enable {
    virtualisation.arion.backend = mkForce "docker";

    virtualisation.arion.projects."invokeai".settings.services."invokeai".service = mkIf cfg.active {
      image = "ghcr.io/invoke-ai/invokeai:v${cfg.version}-cuda";
      container_name = "invokeai";
      env_file = [ "${cfg.envFile}" ];
      ports = [ "${builtins.toString cfg.port}:9090" ];
      volumes = [
        "${cfg.customNodesDir}:/invokeai/custom_nodes"
        "${cfg.legacyConfDir}:/invokeai/configs"
        "${cfg.dbDir}:/invokeai/db"
        "${cfg.downloadCacheDir}:/invokeai/downloads"
        "${cfg.modelsDir}:/invokeai/models"
        "${cfg.outputsDir}:/invokeai/outputs"
        "${cfg.stylePresetsDir}:/invokeai/style_presets"
        "${cfg.workflowThumbnailsDir}:/invokeai/workflow_thumbnails"
      ];
      restart = "unless-stopped";
      devices = [ "nvidia.com/gpu=all" ];
    };

    # Optional system-wide Docker settings
    virtualisation.docker.enable = mkForce true;
    virtualisation.docker.enableOnBoot = mkDefault true;
    hardware.nvidia-container-toolkit.enable = mkForce true;

    # Optional: open firewall
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];
  };
}
