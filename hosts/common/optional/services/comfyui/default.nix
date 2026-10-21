{
  pkgs,
  config,
  inputs,
  lib,
  configVars,
  ...
}:

with lib;

let
  cfg = config.services.comfyui;
  # Container name. The arion- prefix marks it in Komodo's container list as
  # managed here; project, unit, user and paths keep the comfyui-docker name.
  containerName = "arion-comfyui";

  # Model categories the symlinker publishes under sharedModelsPath.
  modelTypes = [
    "checkpoints"
    "clip_vision"
    "controlnet"
    "diffusion_models"
    "embeddings"
    "loras"
    "text_encoders"
    "unet"
    "upscale_models"
    "vae"
  ];

  # Where the read-only shared model tree is mounted in the container. It has to
  # sit outside BASE_DIRECTORY: the image walks every directory under
  # <base>/models, insists each is owned by the container user, and write-tests
  # it with a touch - none of which a read-only Nix store mount can satisfy.
  sharedModelsMount = "/shared-models";

  # ComfyUI's native mechanism for additional model search paths. Points at the
  # mount above, so the Nix-managed models stay read-only and shared with other
  # services (InvokeAI mounts the same directories) rather than being copied in.
  extraModelPaths = pkgs.writeText "comfyui-extra-model-paths.yaml" ''
    nix_store:
      base_path: ${sharedModelsMount}
    ${lib.concatMapStrings (t: "  ${t}: ${t}\n") modelTypes}'';

in
{
  imports = [
    # This module depends on arion for Docker Compose management
    inputs.arion.nixosModules.arion
    inputs.nixified-ai.nixosModules.comfyui
    ./comfyuimini.nix
    ./symlinker.nix
  ];

  options.services.comfyui = {
    useDocker = mkOption {
      type = types.bool;
      default = false;
      description = "Use Docker-based ComfyUI instead of native installation";
    };

    enableNativeAlongside = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable native ComfyUI alongside Docker version.
        Native runs on port 8189, Docker on port 8188.
        Useful for comparing performance or testing.
      '';
    };

    nativePort = mkOption {
      type = types.int;
      default = 8189;
      description = "Port for native ComfyUI when running alongside Docker";
    };

    docker = mkOption {
      type = types.submodule {
        options = {
          image = mkOption {
            type = types.str;
            default = "jamesbrink/comfyui";
            description = "Docker image to use for ComfyUI";
          };

          version = mkOption {
            type = types.str;
            default = "latest";
            description = "Version/tag of the ComfyUI container";
          };

          port = mkOption {
            type = types.int;
            default = 8188;
            description = "Port to access Docker ComfyUI from (defaults to same as native: 8188)";
          };

          workingDir = mkOption {
            type = types.str;
            default = "/var/lib/comfyui-docker";
            description = "Working directory for Docker ComfyUI data";
          };

          environment = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = "Environment variables for the Docker container";
          };

          additionalEnvironmentFile = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Additional environment file for secrets";
          };

          sharedModelsPath = mkOption {
            type = types.str;
            default = "/var/lib/stable-diffusion/models/linked";
            description = "Path to shared models directory (for checkpoints, loras, etc)";
          };

          customNodes = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [
              "https://github.com/ltdrdata/ComfyUI-Manager"
              "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
              "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"
            ];
            description = ''
              List of GitHub URLs for custom nodes to automatically install.
              Nodes are cloned into the persistent custom_nodes directory.
              You can still manually install additional nodes via ComfyUI Manager.
            '';
          };

          workflows = mkOption {
            type = types.attrsOf types.str;
            default = { };
            example = {
              "text-to-video-wan.json" = "https://example.com/workflows/text-to-video.json";
              "image-to-video-wan.json" = "https://example.com/workflows/image-to-video.json";
            };
            description = ''
              Attribute set of workflow files to download.
              Key is the filename to save as, value is the URL to download from.
              Workflows are saved to the persistent user/default/workflows directory.
              You can still manually create/import workflows via ComfyUI UI.
            '';
          };

          models = mkOption {
            type = types.listOf (
              types.submodule {
                options = {
                  url = mkOption {
                    type = types.str;
                    description = "URL to download the model from (supports http/https/huggingface)";
                    example = "https://huggingface.co/tencent/HunyuanVideo/resolve/main/hunyuan-video-t2v-720p/transformers/mp_rank_00_model_states.pt";
                  };
                  destination = mkOption {
                    type = types.str;
                    description = "Destination path relative to the ComfyUI base directory inside the container";
                    example = "models/diffusion_models/hunyuan_video_720_cfgdistill_fp8_e4m3fn.safetensors";
                  };
                  sha256 = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Optional SHA256 hash to verify download";
                    example = "abc123...";
                  };
                };
              }
            );
            default = [ ];
            example = [
              {
                url = "https://huggingface.co/...";
                destination = "models/diffusion_models/model.safetensors";
              }
            ];
            description = ''
              List of model files to automatically download after boot.
              Downloads happen in a separate systemd service that doesn't block boot.
              The service will restart ComfyUI after all models are downloaded.
              Models are only downloaded if they don't already exist.
            '';
          };

          autoUpdate = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Automatically pull a newer ComfyUI container image daily.
              ComfyUI ships in the image, so an update is an image pull plus a
              restart; it rolls back automatically if ComfyUI fails to come back.
              The superseded image is retained tagged `:nixos-rollback`.

              Manual commands:
              - Update now: sudo systemctl start comfyui-update.service
              - Rollback: sudo systemctl start comfyui-rollback.service
              - Check timer: systemctl status comfyui-update.timer
            '';
          };

          gpuType = mkOption {
            type = types.enum [
              "nvidia"
              "amd-rocm"
            ];
            description = ''
              GPU type to use for hardware acceleration.
              - "nvidia": Uses NVIDIA GPU with CUDA via nvidia-container-toolkit
              - "amd-rocm": Uses AMD GPU with ROCm (/dev/kfd and /dev/dri devices)

              By default, this is auto-detected from nixpkgs.config:
              - If rocmSupport is enabled → "amd-rocm"
              - If cudaSupport is enabled → "nvidia" (default)

              You can explicitly override this if needed.
              Note: For ROCm, ensure your user is in the 'render' and 'video' groups.
            '';
          };

          buildFromSource = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Build ComfyUI Docker image with ROCm-compatible PyTorch instead of using the base image directly.
              This is automatically enabled when gpuType is "amd-rocm" since the base image uses CUDA PyTorch.

              The build process extends the official image and replaces PyTorch CUDA with PyTorch ROCm,
              ensuring compatibility with AMD GPUs while preserving all other functionality.
            '';
          };

          securityLevel = mkOption {
            type = types.enum [
              "strong"
              "normal"
              "normal-"
              "weak"
            ];
            default = "normal";
            description = ''
              ComfyUI-Manager's security level, passed to the image as
              SECURITY_LEVEL. 'normal' permits installing packs from the
              registry; installing straight from a git URL additionally needs
              allowGitUrlInstall (which forces this to 'weak').
            '';
          };

          allowGitUrlInstall = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Let ComfyUI-Manager install custom nodes from arbitrary git URLs,
              not just the registry. The image implements this by forcing
              securityLevel to 'weak' and proxying the UI through socat, so only
              enable it where the UI is already behind authentication.
            '';
          };

          allowPipInstall = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Let ComfyUI-Manager install arbitrary pip packages from the UI.
              Carries the same relaxation as allowGitUrlInstall.
            '';
          };

          useNewManager = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Use ComfyUI's built-in manager (--enable-manager) instead of the
              ComfyUI-Manager custom node. Requires a recent ComfyUI core.
            '';
          };

          additionalPipPackages = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [
              "gguf>=0.13.0"
              "sentencepiece"
              "protobuf"
            ];
            description = ''
              List of pip packages to install in the Docker image at build time.
              Automatically enables buildFromSource.

              Only useful for images that run ComfyUI from the image's own
              Python. An image that builds a venv without --system-site-packages
              (as mmartial/comfyui-nvidia-docker does) cannot see these; install
              into its persistent venv instead.
            '';
          };
        };
      };
      default = { };
      description = "Docker-specific configuration options";
    };
  };

  config = mkMerge [
    # Auto-detect GPU type from nixpkgs config (like Ollama does)
    (mkIf cfg.useDocker {
      services.comfyui.docker.gpuType = mkDefault (
        if config.nixpkgs.config.rocmSupport or false then "amd-rocm" else "nvidia"
      );
      # Enable building from source if ROCm or if additional pip packages are specified
      services.comfyui.docker.buildFromSource = mkDefault (
        cfg.docker.gpuType == "amd-rocm" || cfg.docker.additionalPipPackages != [ ]
      );
    })

    # GPU-specific and common configuration
    (mkMerge [
      # NVIDIA-specific configuration
      (mkIf (!cfg.useDocker || (cfg.useDocker && cfg.docker.gpuType == "nvidia")) {
        hardware.nvidia-container-toolkit.enable = mkDefault true;

        nix.settings.trusted-substituters = mkDefault [
          "https://ai.cachix.org"
          "https://cache.nixos-cuda.org"
        ];
        nix.settings.trusted-public-keys = mkDefault [
          "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
          "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        ];
      })

      # AMD ROCm-specific configuration
      (mkIf (cfg.useDocker && cfg.docker.gpuType == "amd-rocm") {
        # Add ROCm cache if available
        nix.settings.trusted-substituters = mkDefault [ "https://ai.cachix.org" ];
        nix.settings.trusted-public-keys = mkDefault [
          "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
        ];
      })

      # Common configuration (secrets, etc.)
      {
        # Ensure secrets are available for model downloads
        sops.secrets."huggingface_key" = mkDefault { };
        sops.secrets."civitai_key" = mkDefault { };
        sops.templates."ai_site_env_keys" = {
          content = ''
            CIVITAI_API_TOKEN=${config.sops.placeholder."civitai_key"}
            HF_TOKEN=${config.sops.placeholder."huggingface_key"}
          '';
          mode = "0755";
        };
        systemd.services.nix-daemon.serviceConfig.EnvironmentFile = [
          config.sops.templates."ai_site_env_keys".path
        ];
      }
    ])

    # Model configuration (used by both native and Docker via symlinker)
    {
      # When using Docker, disable the native comfyui service to avoid IFD from
      # nixified-ai's comfyui package evaluating builtins.readDir on its source.
      # The symlinker uses symlinkPaths != {} as its condition, so it still runs.
      services.comfyui.enable = if cfg.useDocker then mkForce false else mkDefault true;
      services.comfyui.host = mkDefault "0.0.0.0";
      services.comfyui.models = mkDefault (
        pkgs.lib.attrByPath [ config.networking.hostName ] [ ] pkgs.my-sd-models.machineModels
      );
      services.comfyui.customNodes = mkDefault (
        pkgs.lib.attrByPath [ config.networking.hostName ] [ ] pkgs.my-sd-models.machineNodes
      );
    }

    # Native ComfyUI configuration
    (mkIf (!cfg.useDocker || cfg.enableNativeAlongside) {
      networking.firewall.allowedTCPPorts = [
        (if cfg.enableNativeAlongside then cfg.nativePort else 8188)
      ];

      # If running alongside Docker, use different port
      services.comfyui.port = mkIf cfg.enableNativeAlongside cfg.nativePort;

      # Disable cuDNN for better AMD/ROCm performance
      systemd.services.comfyui.environment = mkIf (config.nixpkgs.config.rocmSupport or false) {
        PYTORCH_CUDNN_ENABLED = "0";
      };
    })

    # Docker ComfyUI configuration
    (mkIf cfg.useDocker {
      # Keep comfyui.enable true for model management (symlinker)
      services.comfyui.enable = mkDefault true;

      # Only disable native service if not running alongside
      systemd.services.comfyui.enable = mkIf (!cfg.enableNativeAlongside) (mkForce false);

      # Enable Docker backend
      virtualisation.arion.backend = mkForce "docker";
      virtualisation.docker.enable = mkForce true;
      virtualisation.docker.enableOnBoot = mkDefault true;

      # Arion runs `arion up` attached, so a stop that outruns the systemd stop
      # timeout can leave the container behind. Removing it before starting
      # avoids reusing a container that is up but detached from its bridge
      # network, and waiting for the name to be released avoids racing the
      # daemon's teardown (which fails the start with a name conflict).
      # Container data lives on host volumes under cfg.docker.workingDir, so
      # recreating the container doesn't lose state.
      services.arion-container-cleanup.projects.comfyui-docker.containers = [ containerName ];

      networking.firewall.allowedTCPPorts = mkIf (cfg.docker.port != null) [ cfg.docker.port ];

      # Refuse to start unless the working directory's filesystem is actually
      # mounted. Where workingDir is its own volume a silent mount failure would
      # otherwise leave the container writing a fresh venv and model tree onto
      # the root filesystem, which is slow to notice and fills the disk.
      systemd.services.arion-comfyui-docker.unitConfig.RequiresMountsFor = cfg.docker.workingDir;

      # Define comfyui-docker group for jamesbrink/comfyui image (uses UID/GID 10001)
      users.groups.comfyui-docker.gid = 10001;
      users.users.comfyui-docker = {
        isSystemUser = true;
        uid = 10001;
        group = "comfyui-docker";
        home = cfg.docker.workingDir;
        # Add to render/video groups for ROCm GPU access
        extraGroups = mkIf (cfg.docker.gpuType == "amd-rocm") [
          "render"
          "video"
        ];
      };

      # Create necessary directories with proper permissions
      # jamesbrink/comfyui container runs as user "comfyui" with UID/GID 10001
      systemd.tmpfiles.rules =
        let
          # Use GID for both UID and GID to match container's comfyui user (10001:10001)
          uid = toString config.users.users.comfyui-docker.uid;
          gid = toString config.users.groups.comfyui-docker.gid;
        in
        [
          "d ${cfg.docker.workingDir} 0775 ${uid} ${gid} - -"
          # The image's run directory: it clones ComfyUI and builds the venv in
          # here, so it must be writable by the container user and on a mount
          # that permits exec (see the subvolume options in smeagol's hardware
          # configuration - a venv's .so files are mmapped PROT_EXEC).
          "d ${cfg.docker.workingDir}/run 0775 ${uid} ${gid} - -"
          # ComfyUI's --base-directory. Its subdirectories are bind-mounted over
          # the top, but the parent itself has to exist and be writable or the
          # image's init refuses to start.
          "d ${cfg.docker.workingDir}/basedir 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/models 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/outputs 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/inputs 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/custom_nodes 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/user 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/user/default 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/user/default/workflows 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/user/default/temp 0775 ${uid} ${gid} - -"
        ];

      # Two things can be stale. ComfyUI itself is a git checkout the image made
      # in the run volume and never updates on its own, so it needs a pull; the
      # runtime around it (CUDA, Python, torch) comes from the image, so that
      # needs a docker pull. Do both. Rolling back restores the image tag and the
      # ComfyUI commit recorded before the update; user data is untouched either
      # way, and the venv is rebuilt by the image's init when the base changes.
      systemd.services.comfyui-update = {
        description = "Update the ComfyUI container image to the latest version";

        serviceConfig.Type = "oneshot";

        path = [ pkgs.git ];

        script =
          let
            docker = "${pkgs.docker}/bin/docker";
            baseImage = "${cfg.docker.image}:${cfg.docker.version}";
            rollbackImage = "${cfg.docker.image}:nixos-rollback";
            # Image docker compose builds for us when buildFromSource is set,
            # named <project>-<service>. Removing it forces `arion up` to rebuild.
            builtImage = "comfyui-docker-comfyui-docker";
          in
          ''
            set -euo pipefail

            restart_comfyui() {
              systemctl stop arion-comfyui-docker.service || true
              ${lib.optionalString cfg.docker.buildFromSource ''
                # Drop the derived image so the new base layer is picked up.
                ${docker} image rm -f ${builtImage} || true
              ''}
              systemctl start arion-comfyui-docker.service
            }

            comfyui_responds() {
              for _ in $(seq 1 60); do
                if ${pkgs.curl}/bin/curl -sf http://localhost:${toString cfg.docker.port}/system_stats >/dev/null; then
                  return 0
                fi
                sleep 5
              done
              return 1
            }

            comfy_src=${cfg.docker.workingDir}/run/ComfyUI

            OLD_ID="$(${docker} image inspect --format '{{.Id}}' ${baseImage} 2>/dev/null || true)"
            OLD_COMMIT="$(git -C "$comfy_src" rev-parse HEAD 2>/dev/null || true)"

            echo "Pulling ${baseImage}..."
            ${docker} pull ${baseImage}

            NEW_ID="$(${docker} image inspect --format '{{.Id}}' ${baseImage})"

            # ComfyUI is a checkout the image made in the run volume and never
            # refreshes, so pull it here. Done with the container stopped so
            # nothing is importing from the tree mid-update.
            systemctl stop arion-comfyui-docker.service || true
            if [ -d "$comfy_src/.git" ]; then
              echo "Updating the ComfyUI checkout..."
              git -C "$comfy_src" pull --ff-only || echo "Warning: ComfyUI pull failed, keeping $OLD_COMMIT"
            fi
            NEW_COMMIT="$(git -C "$comfy_src" rev-parse HEAD 2>/dev/null || true)"

            if [ "$OLD_ID" = "$NEW_ID" ] && [ "$OLD_COMMIT" = "$NEW_COMMIT" ]; then
              echo "Image and ComfyUI checkout both already current."
              systemctl start arion-comfyui-docker.service
              exit 0
            fi

            if [ -n "$OLD_ID" ] && [ "$OLD_ID" != "$NEW_ID" ]; then
              echo "Tagging the previous image as ${rollbackImage}"
              ${docker} tag "$OLD_ID" ${rollbackImage}
            fi
            [ -n "$OLD_COMMIT" ] && echo "$OLD_COMMIT" > ${cfg.docker.workingDir}/run/.rollback-commit

            restart_comfyui

            if comfyui_responds; then
              echo "ComfyUI updated and responding on port ${toString cfg.docker.port}."
            else
              echo "ComfyUI did not come back after the update."
              if [ -n "$OLD_ID" ] || [ -n "$OLD_COMMIT" ]; then
                echo "Rolling back..."
                [ -n "$OLD_ID" ] && ${docker} tag "$OLD_ID" ${baseImage}
                [ -n "$OLD_COMMIT" ] && git -C "$comfy_src" reset --hard "$OLD_COMMIT"
                restart_comfyui
              fi
              exit 1
            fi
          '';
      };

      # Manual rollback: systemctl start comfyui-rollback.service
      systemd.services.comfyui-rollback = {
        description = "Roll the ComfyUI container image back to the previous version";

        serviceConfig.Type = "oneshot";

        path = [ pkgs.git ];

        script =
          let
            docker = "${pkgs.docker}/bin/docker";
            baseImage = "${cfg.docker.image}:${cfg.docker.version}";
            rollbackImage = "${cfg.docker.image}:nixos-rollback";
            builtImage = "comfyui-docker-comfyui-docker";
          in
          ''
            set -euo pipefail

            comfy_src=${cfg.docker.workingDir}/run/ComfyUI
            commit_file=${cfg.docker.workingDir}/run/.rollback-commit

            if ! ${docker} image inspect ${rollbackImage} >/dev/null 2>&1 && [ ! -f "$commit_file" ]; then
              echo "Nothing to roll back to: no ${rollbackImage} image and no recorded commit."
              exit 1
            fi

            if ${docker} image inspect ${rollbackImage} >/dev/null 2>&1; then
              ${docker} tag ${rollbackImage} ${baseImage}
            fi

            systemctl stop arion-comfyui-docker.service || true

            if [ -f "$commit_file" ]; then
              echo "Restoring the ComfyUI checkout to $(cat "$commit_file")"
              git -C "$comfy_src" reset --hard "$(cat "$commit_file")" || true
            fi
            ${lib.optionalString cfg.docker.buildFromSource ''
              ${docker} image rm -f ${builtImage} || true
            ''}
            systemctl start arion-comfyui-docker.service

            echo "Rolled back to ${rollbackImage}; check journalctl -u arion-comfyui-docker.service"
          '';
      };

      # Systemd timer for automatic daily update checks
      systemd.timers.comfyui-update = mkIf (cfg.docker.autoUpdate or false) {
        description = "Daily check for ComfyUI updates";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };

      # Arion project for Docker ComfyUI
      virtualisation.arion.projects."comfyui-docker".settings = {
        services."comfyui-docker".service = mkMerge [
          # Base configuration
          {
            container_name = containerName;
            labels."org.nix-config.managed-by" = "arion: change it in nix-config, not here";
            environment = {
              # Remap the image's user onto the host's comfyui-docker account so
              # everything it writes to the volumes lands with the right owner.
              WANTED_UID = toString config.users.users.comfyui-docker.uid;
              WANTED_GID = toString config.users.groups.comfyui-docker.gid;
              # Everything mutable lives under ComfyUI's --base-directory.
              BASE_DIRECTORY = "/basedir";
              SECURITY_LEVEL = cfg.docker.securityLevel;
              ALLOW_GIT_URL_INSTALL = lib.boolToString cfg.docker.allowGitUrlInstall;
              ALLOW_PIP_INSTALL = lib.boolToString cfg.docker.allowPipInstall;
              USE_NEW_MANAGER = lib.boolToString cfg.docker.useNewManager;
              # The bind mounts are already owned correctly; a recursive chown
              # over the model trees would be slow and would fail on read-only
              # mounts anyway.
              FORCE_CHOWN = "false";
            }
            # Extra ComfyUI flags go through the image's own variable rather
            # than `command`, which would replace its init script's argv.
            // {
              COMFY_CMDLINE_EXTRA = lib.concatStringsSep " " (
                [ "--extra-model-paths-config /basedir/extra_model_paths.yaml" ]
                ++ lib.optional (cfg.docker.environment ? CLI_ARGS) cfg.docker.environment.CLI_ARGS
              );
            }
            // lib.removeAttrs cfg.docker.environment [ "CLI_ARGS" ];
            env_file = lib.optionals (cfg.docker.additionalEnvironmentFile != null) [
              "${cfg.docker.additionalEnvironmentFile}"
            ];
            # No entrypoint override: the image's /comfyui-nvidia_init.bash
            # checks out ComfyUI, builds the venv and remaps the container user,
            # and is mount-aware (it won't chown or chmod a bind mount).
            ports = [ "${builtins.toString cfg.docker.port}:8188" ];
            # Two mounts carry everything. /comfy/mnt is the run directory: the
            # ComfyUI checkout, the venv and the pip/HF caches, all of which the
            # image creates and owns. /basedir is ComfyUI's --base-directory,
            # holding the data we care about; its subdirectories are mounted on
            # top so the existing host layout is reused as-is.
            volumes = [
              # Model symlinks under sharedModelsPath point into the store. The
              # image has no /nix of its own, so mounting the host store here
              # shadows nothing - no need for symlinker's /mnt-translated
              # -arion variants, which are for nix-built images.
              "/nix/store:/nix/store:ro"
              "${cfg.docker.workingDir}/run:/comfy/mnt"
              "${cfg.docker.workingDir}/basedir:/basedir"
              "${cfg.docker.workingDir}/custom_nodes:/basedir/custom_nodes"
              "${cfg.docker.workingDir}/models:/basedir/models"
              "${cfg.docker.workingDir}/inputs:/basedir/input"
              "${cfg.docker.workingDir}/outputs:/basedir/output"
              "${cfg.docker.workingDir}/user:/basedir/user"
              # Declaratively managed models from the Nix store (via symlinker),
              # reached through extra_model_paths.yaml rather than being mounted
              # under /basedir - see sharedModelsMount.
              "${extraModelPaths}:/basedir/extra_model_paths.yaml:ro"
            ]
            ++ map (t: "${cfg.docker.sharedModelsPath}/${t}:${sharedModelsMount}/${t}:ro") modelTypes;
            restart = "unless-stopped";
            devices =
              if cfg.docker.gpuType == "nvidia" then
                [ "nvidia.com/gpu=all" ]
              else if cfg.docker.gpuType == "amd-rocm" then
                [
                  "/dev/kfd:/dev/kfd"
                  "/dev/dri:/dev/dri"
                ]
              else
                [ ];
          }

          # Use pre-built image (default for NVIDIA)
          (mkIf (!cfg.docker.buildFromSource) {
            image = "${cfg.docker.image}:${cfg.docker.version}";
          })

          # Build from Dockerfile with optional ROCm support and additional pip packages
          (mkIf cfg.docker.buildFromSource (
            let
              # Generate pip install command for additional packages. RUN is
              # shell-form, so version specifiers have to be quoted or the shell
              # eats '<' and '>' as redirections and the pins silently vanish.
              pipInstallCmd =
                if cfg.docker.additionalPipPackages != [ ] then
                  "pip install --no-cache-dir ${
                    lib.concatMapStringsSep " " lib.escapeShellArg cfg.docker.additionalPipPackages
                  }"
                else
                  "echo 'No additional pip packages to install'";

              # Create a Dockerfile that extends the official image
              dockerfile = pkgs.writeText "Dockerfile.comfyui-custom" ''
                FROM ${cfg.docker.image}:${cfg.docker.version}

                USER root

                # Install additional pip packages (baked into image, survives ephemeral wipe)
                ${
                  if cfg.docker.additionalPipPackages != [ ] then
                    "RUN ${pipInstallCmd}"
                  else
                    "# No additional pip packages specified"
                }

                ${
                  if cfg.docker.gpuType == "amd-rocm" then
                    ''
                      # Install ROCm-compatible PyTorch for RDNA 3.5 (Strix Halo / Ryzen AI Max+ 365)
                      # This replaces the CUDA PyTorch with the correct ROCm version for gfx1151
                      RUN pip uninstall -y torch torchvision torchaudio && \
                          pip install --pre torch torchvision torchaudio \
                            --index-url https://rocm.nightlies.amd.com/v2/gfx1151/

                      # Set environment for Strix Halo (gfx1151)
                      ENV HSA_OVERRIDE_GFX_VERSION=11.5.1
                      ENV ROCM_HOME=/opt/rocm

                      # Disable cuDNN for better AMD/ROCm performance
                      ENV PYTORCH_CUDNN_ENABLED=0
                    ''
                  else
                    ""
                }

                USER comfyui
              '';

              buildContext = pkgs.runCommand "comfyui-custom-context" { } ''
                mkdir -p $out
                cp ${dockerfile} $out/Dockerfile
              '';
            in
            {
              build = {
                context = "${buildContext}";
                dockerfile = "Dockerfile";
              };
            }
          ))
        ];
      };

      # Systemd service to install declared custom nodes and workflows
      systemd.services.comfyui-install-custom-nodes =
        mkIf (cfg.docker.customNodes != [ ] || cfg.docker.workflows != { })
          {
            description = "Install ComfyUI custom nodes and workflows";
            after = [ "arion-comfyui-docker.service" ];
            requires = [ "arion-comfyui-docker.service" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              Restart = "on-failure";
              RestartSec = "10s";
              # Load API keys for authenticated downloads
              EnvironmentFile = [ config.sops.templates."ai_site_env_keys".path ];
            };

            script =
              let
                # Clone and update nodes declaratively (git operations only)
                nodeManagementScript = concatStringsSep "\n" (
                  map (
                    nodeUrl:
                    let
                      nodeName = builtins.baseNameOf nodeUrl;
                    in
                    ''
                      echo "Managing custom node: ${nodeName}..."
                      if ! ${pkgs.docker}/bin/docker exec -u comfy ${containerName} [ -d /basedir/custom_nodes/${nodeName}/.git ]; then
                        echo "  → Cloning ${nodeName} from ${nodeUrl}..."
                        ${pkgs.docker}/bin/docker exec -u comfy ${containerName} bash -c "
                          cd /basedir/custom_nodes && \
                          git clone ${nodeUrl}
                        " && echo "  ✓ Successfully cloned ${nodeName}" || echo "  ✗ Failed to clone ${nodeName}"
                      else
                        echo "  → Updating ${nodeName}..."
                        ${pkgs.docker}/bin/docker exec -u comfy ${containerName} bash -c "
                          cd /basedir/custom_nodes/${nodeName} && \
                          git fetch origin && \
                          if ! git diff --quiet HEAD origin/HEAD 2>/dev/null; then
                            echo '  → Changes detected, updating...' && \
                            git stash && \
                            git pull --rebase && \
                            git stash pop || true
                          else
                            echo '  ✓ Already up to date'
                          fi
                        " || echo "  ✗ Failed to update ${nodeName}"
                      fi
                    ''
                  ) cfg.docker.customNodes
                );

                workflowInstallScript = concatStringsSep "\n" (
                  mapAttrsToList (filename: url: ''
                    echo "Checking workflow: ${filename}..."
                    if ! ${pkgs.docker}/bin/docker exec -u comfy ${containerName} [ -f /basedir/user/default/workflows/${filename} ]; then
                      echo "  → Downloading ${filename}..."

                      # Build curl command with authentication if needed
                      CURL_CMD="${pkgs.curl}/bin/curl -fsSL"

                      # Add HuggingFace authentication if URL is from HuggingFace
                      if [[ "${url}" == *"huggingface.co"* ]] && [ -n "$HF_TOKEN" ]; then
                        CURL_CMD="$CURL_CMD -H \"Authorization: Bearer $HF_TOKEN\""
                      fi

                      # Add CivitAI authentication if URL is from CivitAI
                      if [[ "${url}" == *"civitai.com"* ]] && [ -n "$CIVITAI_API_TOKEN" ]; then
                        CURL_CMD="$CURL_CMD -H \"Authorization: Bearer $CIVITAI_API_TOKEN\""
                      fi

                      # Download workflow
                      eval "$CURL_CMD \"${url}\" -o /tmp/${filename}" && \
                      ${pkgs.docker}/bin/docker cp /tmp/${filename} ${containerName}:/basedir/user/default/workflows/${filename} && \
                      rm /tmp/${filename} && \
                      echo "  ✓ Successfully downloaded ${filename}" || \
                      echo "  ✗ Failed to download ${filename}"
                    else
                      echo "  ✓ ${filename} already exists"
                    fi
                  '') cfg.docker.workflows
                );
              in
              ''
                # Wait for container to be fully ready
                echo "========================================"
                echo "ComfyUI Custom Node Manager"
                echo "========================================"
                echo "Waiting for container..."
                for i in {1..30}; do
                  if ${pkgs.docker}/bin/docker exec -u comfy ${containerName} test -d /basedir/custom_nodes; then
                    echo "✓ Container is ready!"
                    break
                  fi
                  sleep 2
                done

                # Clone and update all declared custom nodes
                echo ""
                echo "Managing custom nodes (git operations only)..."
                echo "Python dependencies will be installed by the container entrypoint."
                echo "----------------------------------------"
                ${nodeManagementScript}

                # Download each declared workflow
                if [ -n "${workflowInstallScript}" ]; then
                  echo ""
                  echo "Managing workflows..."
                  echo "----------------------------------------"
                  ${workflowInstallScript}
                fi

                echo ""
                echo "========================================"
                echo "✓ Custom node management complete!"
                echo "The container will install Python dependencies on next restart."
                echo "========================================"
              '';
          };

      # Systemd service to download declared model files (runs after boot, doesn't block)
      systemd.services.comfyui-download-models = mkIf (cfg.docker.models != [ ]) {
        description = "Download ComfyUI model files";
        after = [
          "arion-comfyui-docker.service"
          "network-online.target"
        ];
        wants = [ "network-online.target" ];
        requires = [ "arion-comfyui-docker.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "30s";
          # Don't timeout on large downloads
          TimeoutStartSec = "infinity";
          # Load API keys for authenticated downloads
          EnvironmentFile = [ config.sops.templates."ai_site_env_keys".path ];
        };

        script =
          let
            modelDownloadScript = concatStringsSep "\n" (
              map (
                model:
                let
                  filename = builtins.baseNameOf model.destination;
                  dirname = builtins.dirOf model.destination;
                  sha256Check =
                    if model.sha256 != null then
                      ''
                        echo "Verifying SHA256 hash..."
                        echo "${model.sha256}  /tmp/${filename}" | sha256sum -c - || {
                          echo "ERROR: SHA256 hash mismatch for ${filename}!"
                          rm /tmp/${filename}
                          exit 1
                        }
                      ''
                    else
                      "";
                in
                ''
                  echo "================================"
                  echo "Checking model: ${filename}"
                  echo "Destination: ${model.destination}"

                  if ${pkgs.docker}/bin/docker exec -u comfy ${containerName} [ -f /basedir/${model.destination} ]; then
                    echo "${filename} already exists, skipping..."
                  else
                    MODELS_DOWNLOADED=true
                    echo "Creating destination directory if needed..."
                    ${pkgs.docker}/bin/docker exec -u comfy ${containerName} mkdir -p /basedir/${dirname}

                    echo "Downloading ${filename} from ${model.url}"
                    echo "This may take a while for large models..."

                    # Build curl command with authentication if needed
                    CURL_CMD="${pkgs.curl}/bin/curl -fL --progress-bar"

                    # Add HuggingFace authentication if URL is from HuggingFace
                    if [[ "${model.url}" == *"huggingface.co"* ]]; then
                      if [ -n "$HF_TOKEN" ]; then
                        echo "Using HuggingFace authentication..."
                        CURL_CMD="$CURL_CMD -H \"Authorization: Bearer $HF_TOKEN\""
                      fi
                    fi

                    # Add CivitAI authentication if URL is from CivitAI
                    if [[ "${model.url}" == *"civitai.com"* ]]; then
                      if [ -n "$CIVITAI_API_TOKEN" ]; then
                        echo "Using CivitAI authentication..."
                        CURL_CMD="$CURL_CMD -H \"Authorization: Bearer $CIVITAI_API_TOKEN\""
                      fi
                    fi

                    # Download to temp location first
                    eval "$CURL_CMD \"${model.url}\" -o /tmp/${filename}" || {
                      echo "ERROR: Failed to download ${filename}"
                      rm -f /tmp/${filename}
                      exit 1
                    }

                    ${sha256Check}

                    echo "Copying ${filename} to container..."
                    ${pkgs.docker}/bin/docker cp /tmp/${filename} ${containerName}:/basedir/${model.destination} && \
                    rm /tmp/${filename} && \
                    echo "Successfully installed ${filename}" || {
                      echo "ERROR: Failed to copy ${filename} to container"
                      rm -f /tmp/${filename}
                      exit 1
                    }
                  fi
                ''
              ) cfg.docker.models
            );
          in
          ''
            # Track whether any models were downloaded
            MODELS_DOWNLOADED=false

            echo "========================================"
            echo "ComfyUI Model Download Service Starting"
            echo "========================================"

            # Wait for container to be fully ready
            echo "Waiting for ComfyUI container to be ready..."
            for i in {1..30}; do
              if ${pkgs.docker}/bin/docker exec -u comfy ${containerName} test -d /basedir/models; then
                echo "Container is ready!"
                break
              fi
              echo "Waiting... ($i/30)"
              sleep 2
            done

            # Download each declared model
            ${modelDownloadScript}

            # Restart ComfyUI to load new models (only if something new was downloaded)
            if [ "$MODELS_DOWNLOADED" = "true" ]; then
              echo "========================================"
              echo "New models were downloaded!"
              echo "Restarting ComfyUI to load new models..."
              echo "========================================"
              systemctl restart arion-comfyui-docker.service || true
              sleep 5
              echo "ComfyUI restart complete!"
            else
              echo "All models already present, no restart needed."
            fi

            echo "========================================"
            echo "Model download service complete!"
            echo "========================================"
          '';
      };
    })
  ];
}
