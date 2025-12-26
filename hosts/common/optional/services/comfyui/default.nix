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
in
{
  imports = [
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
                    description = "Destination path relative to /data inside container";
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
              Automatically check for ComfyUI updates daily.
              When enabled, a systemd timer will check for updates once per day.
              Updates are applied automatically with automatic rollback on failure.
              Backups are kept in /var/lib/comfyui-backups (last 3 backups retained).

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
    })

    # GPU-specific and common configuration
    (mkMerge [
      # NVIDIA-specific configuration
      (mkIf (!cfg.useDocker || (cfg.useDocker && cfg.docker.gpuType == "nvidia")) {
        hardware.nvidia-container-toolkit.enable = mkDefault true;

        nix.settings.trusted-substituters = mkDefault [
          "https://ai.cachix.org"
          "https://cuda-maintainers.cachix.org"
        ];
        nix.settings.trusted-public-keys = mkDefault [
          "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
          "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
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
      services.comfyui.enable = mkDefault true;
      services.comfyui.host = mkDefault "0.0.0.0";
      services.comfyui.models = mkDefault (
        pkgs.lib.attrByPath [ config.networking.hostName ] [ ] pkgs.my-sd-models.machineModels
      );
      services.comfyui.customNodes = mkDefault (
        pkgs.lib.attrByPath [ config.networking.hostName ] [ ] pkgs.my-sd-models.machineNodes
      );
    }

    # Native ComfyUI-only configuration
    (mkIf (!cfg.useDocker) {
      networking.firewall.allowedTCPPorts = [ 8188 ];
    })

    # Docker ComfyUI configuration
    (mkIf cfg.useDocker {
      # Keep comfyui.enable true for model management (symlinker), but prevent service from starting
      services.comfyui.enable = mkDefault true;
      systemd.services.comfyui.enable = mkForce false; # Disable the actual native service

      # Enable Docker backend
      virtualisation.arion.backend = mkForce "docker";
      virtualisation.docker.enable = mkForce true;
      virtualisation.docker.enableOnBoot = mkDefault true;

      networking.firewall.allowedTCPPorts = mkIf (cfg.docker.port != null) [ cfg.docker.port ];

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
          "d ${cfg.docker.workingDir}/models 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/outputs 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/inputs 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/custom_nodes 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/user 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/user/default 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/user/default/workflows 0775 ${uid} ${gid} - -"
          "d ${cfg.docker.workingDir}/user/default/temp 0775 ${uid} ${gid} - -"
          "d /var/lib/comfyui-backups 0755 root root - -"
        ];

      # Systemd service to update ComfyUI to latest version
      systemd.services.comfyui-update = {
        description = "Update ComfyUI Docker container to latest version";

        serviceConfig = {
          Type = "oneshot";
        };

        script = ''
          BACKUP_DIR="/var/lib/comfyui-backups"
          TIMESTAMP=$(date +%Y%m%d-%H%M%S)

          # Create backup directory if it doesn't exist
          mkdir -p "$BACKUP_DIR"

          # Function to create backup
          create_backup() {
            echo "Creating backup of current ComfyUI version..."
            ${pkgs.docker}/bin/docker exec comfyui-docker bash -c "
              tar -czf /tmp/comfyui-backup-$TIMESTAMP.tar.gz -C /data work
            "
            ${pkgs.docker}/bin/docker cp comfyui-docker:/tmp/comfyui-backup-$TIMESTAMP.tar.gz "$BACKUP_DIR/"
            ${pkgs.docker}/bin/docker exec comfyui-docker rm /tmp/comfyui-backup-$TIMESTAMP.tar.gz
            echo "✓ Backup created: comfyui-backup-$TIMESTAMP.tar.gz"
            
            # Keep only the last 3 backups
            cd "$BACKUP_DIR"
            ls -t comfyui-backup-*.tar.gz | tail -n +4 | xargs -r rm
            echo "✓ Old backups cleaned (keeping last 3)"
          }

          # Function to restore from backup
          restore_backup() {
            local backup_file="$1"
            echo "⚠️  Update failed! Restoring from backup: $backup_file"
            
            ${pkgs.docker}/bin/docker cp "$backup_file" comfyui-docker:/tmp/restore.tar.gz
            ${pkgs.docker}/bin/docker exec comfyui-docker bash -c "
              cd /data
              rm -rf work
              tar -xzf /tmp/restore.tar.gz -C /data
              rm /tmp/restore.tar.gz
            "
            
            echo "✓ Restored from backup"
            systemctl restart arion-comfyui-docker.service
            echo "✓ ComfyUI restarted with previous version"
          }

          # Function to test if ComfyUI starts successfully
          test_comfyui() {
            echo "Testing if ComfyUI starts successfully..."
            for i in {1..30}; do
              if curl -s http://localhost:8188/object_info >/dev/null 2>&1; then
                echo "✓ ComfyUI is responding!"
                return 0
              fi
              sleep 2
            done
            echo "✗ ComfyUI failed to start within 60 seconds"
            return 1
          }
        ''
        + ''
          echo "========================================"
          echo "ComfyUI Update Service"
          echo "========================================"

          # Wait for container to be fully started
          echo "Waiting for ComfyUI container to be ready..."
          for i in {1..30}; do
            if ${pkgs.docker}/bin/docker exec comfyui-docker test -d /data/work 2>/dev/null; then
              echo "Container is ready!"
              break
            fi
            echo "Waiting... ($i/30)"
            sleep 2
          done

          # Check current version
          CURRENT_VERSION=$(${pkgs.docker}/bin/docker exec comfyui-docker cat /data/work/comfyui_version.py 2>/dev/null | grep __version__ || echo "Unable to determine")
          echo "Current version: $CURRENT_VERSION"

          # Check latest version on GitHub
          echo "Checking for updates..."
          LATEST_COMMIT=$(${pkgs.docker}/bin/docker exec comfyui-docker bash -c "git ls-remote https://github.com/comfyanonymous/ComfyUI.git refs/heads/master | cut -f1 | head -c7" 2>/dev/null || echo "unknown")
          echo "Latest commit on GitHub: $LATEST_COMMIT"

          # Create backup before updating
          create_backup
          BACKUP_FILE="$BACKUP_DIR/comfyui-backup-$TIMESTAMP.tar.gz"

          # Stop ComfyUI process
          echo "Stopping ComfyUI..."
          ${pkgs.docker}/bin/docker exec comfyui-docker pkill -f "python3 main.py" || true
          sleep 2

          # Clone latest ComfyUI to temp location
          echo "Downloading latest ComfyUI from GitHub..."
          if ! ${pkgs.docker}/bin/docker exec comfyui-docker bash -c "
            rm -rf /tmp/comfyui-update
            git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /tmp/comfyui-update
          "; then
            echo "✗ Failed to download latest ComfyUI"
            restore_backup "$BACKUP_FILE"
            exit 1
          fi

          # Update the working directory (preserve custom_nodes, models, etc.)
          echo "Updating ComfyUI files..."
          if ! ${pkgs.docker}/bin/docker exec comfyui-docker bash -c "
            cd /data/work
            # Remove old symlinks and copy new files
            # Only exclude TOP-LEVEL directories, not nested ones (ldm/models/ contains Python code!)
            find . -maxdepth 1 -type l -delete
            rsync -av --exclude='/custom_nodes' --exclude='/models' --exclude='/input' --exclude='/output' --exclude='/user' /tmp/comfyui-update/ /data/work/
            rm -rf /tmp/comfyui-update
          "; then
            echo "✗ Failed to update files"
            restore_backup "$BACKUP_FILE"
            exit 1
          fi

          # Restart ComfyUI container
          echo "Restarting ComfyUI container..."
          systemctl restart arion-comfyui-docker.service

          sleep 15

          # Test if ComfyUI starts successfully
          if ! test_comfyui; then
            echo "✗ ComfyUI failed to start after update"
            restore_backup "$BACKUP_FILE"
            exit 1
          fi

          # Verify update
          NEW_VERSION=$(${pkgs.docker}/bin/docker exec comfyui-docker cat /data/work/comfyui_version.py 2>/dev/null | grep __version__ || echo "unknown")
          echo "========================================"
          echo "✓ ComfyUI updated successfully!"
          echo "New version: $NEW_VERSION"
          echo "Backup saved: $BACKUP_FILE"
          echo "Access ComfyUI at: http://smeagol:8188"
          echo "========================================"
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

      # Manual rollback service
      systemd.services.comfyui-rollback = {
        description = "Rollback ComfyUI to previous backup";

        serviceConfig = {
          Type = "oneshot";
        };

        script = ''
          BACKUP_DIR="/var/lib/comfyui-backups"

          # Find the most recent backup
          LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/comfyui-backup-*.tar.gz 2>/dev/null | head -1)

          if [ -z "$LATEST_BACKUP" ]; then
            echo "✗ No backups found in $BACKUP_DIR"
            exit 1
          fi

          echo "========================================"
          echo "ComfyUI Rollback Service"
          echo "========================================"
          echo "Rolling back to: $(basename "$LATEST_BACKUP")"

          # Stop ComfyUI
          ${pkgs.docker}/bin/docker exec comfyui-docker pkill -f "python3 main.py" || true
          sleep 2

          # Restore backup
          ${pkgs.docker}/bin/docker cp "$LATEST_BACKUP" comfyui-docker:/tmp/restore.tar.gz
          ${pkgs.docker}/bin/docker exec comfyui-docker bash -c "
            cd /data
            rm -rf work
            tar -xzf /tmp/restore.tar.gz -C /data
            rm /tmp/restore.tar.gz
          "

          echo "✓ Backup restored"

          # Restart ComfyUI
          systemctl restart arion-comfyui-docker.service

          sleep 15

          # Test if it works
          for i in {1..30}; do
            if curl -s http://localhost:8188/object_info >/dev/null 2>&1; then
              echo "========================================"
              echo "✓ Rollback successful!"
              echo "ComfyUI is running"
              echo "========================================"
              exit 0
            fi
            sleep 2
          done

          echo "⚠️  Rollback completed but ComfyUI may not be responding"
          echo "Check logs: journalctl -u arion-comfyui-docker.service -f"
        '';
      };

      # Patch the original entrypoint from jamesbrink/comfyui Docker image
      # Extract at runtime and patch to skip automatic pip installs while preserving all other setup
      systemd.services.comfyui-patch-entrypoint = {
        description = "Extract and patch ComfyUI entrypoint to skip auto pip install";
        before = [ "arion-comfyui-docker.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
                    # Ensure directory exists and clean up any old file/directory
                    mkdir -p /etc/comfyui
                    rm -rf /etc/comfyui/custom-entrypoint.sh

                    # Extract entrypoint from the Docker image (override entrypoint to use sh for file extraction)
                    echo "Extracting entrypoint from ${cfg.docker.image}:${cfg.docker.version}..."
                    ENTRYPOINT=$(${pkgs.docker}/bin/docker run --rm --entrypoint cat ${cfg.docker.image}:${cfg.docker.version} /usr/local/bin/entrypoint.sh)

                    # Apply minimal patch:
                    # 1. Comment out setup_custom_nodes call to skip pip installs  
                    # 2. Add 'user' to the symlinked directories (originally only models/output/input)
                    # 3. Add --base-directory and --listen flags for proper remote access
                    # 4. Skip automatic installation of recommended custom nodes
                    # 5. Make Python packages ephemeral by removing .local and .cache on each boot
                    echo "$ENTRYPOINT" | \
                      sed 's/^setup_custom_nodes$/# setup_custom_nodes # PATCHED: Managed declaratively by NixOS/' | \
                      sed 's/for dir in models output input;/for dir in models output input user;/' | \
                      sed 's/flags="--listen --port 8188 --preview-method auto --multi-user"/flags="--listen 0.0.0.0 --port 8188 --preview-method auto --multi-user --base-directory \/data\/work"/' | \
                      sed 's/comfy node install --mode remote/# comfy node install --mode remote # PATCHED: Skipped automatic node installation/' | \
                      sed '/^# Main execution$/a\
          # PATCHED: Make Python user packages ephemeral to prevent corruption\
          # Remove ALL user-installed packages on each boot to avoid corrupted shared objects\
          # ComfyUI-Manager will reinstall them automatically, but they will be fresh\
          echo "Resetting ephemeral Python packages..."\
          rm -rf /data/user/.local /data/user/.cache 2>/dev/null || true\
          echo "Python packages will be reinstalled fresh on this boot"' | \
                      sed 's/exec python3 main.py "\$@"/exec python3 main.py --listen 0.0.0.0 --port 8188 --base-directory \/data\/work "\$@"/' \
                      > /etc/comfyui/custom-entrypoint.sh

                    chmod +x /etc/comfyui/custom-entrypoint.sh

                    echo "✓ Patched entrypoint created successfully at /etc/comfyui/custom-entrypoint.sh"
        '';
      };

      # Arion project for Docker ComfyUI
      virtualisation.arion.projects."comfyui-docker".settings = {
        services."comfyui-docker".service = {
          image = "${cfg.docker.image}:${cfg.docker.version}";
          container_name = "comfyui-docker";
          environment = cfg.docker.environment;
          env_file = lib.optionals (cfg.docker.additionalEnvironmentFile != null) [
            "${cfg.docker.additionalEnvironmentFile}"
          ];
          # Override entrypoint to use our custom script that skips pip install
          entrypoint = "/etc/comfyui/custom-entrypoint.sh";
          command = lib.optionalString (cfg.docker.environment ? CLI_ARGS) cfg.docker.environment.CLI_ARGS;
          ports = [ "${builtins.toString cfg.docker.port}:8188" ];
          volumes = [
            "/nix/store:/nix/store:ro"
            "/etc/comfyui/custom-entrypoint.sh:/etc/comfyui/custom-entrypoint.sh:ro"
            "${cfg.docker.workingDir}/models:/data/models"
            "${cfg.docker.workingDir}/outputs:/data/output"
            "${cfg.docker.workingDir}/inputs:/data/input"
            "${cfg.docker.workingDir}/custom_nodes:/data/custom_nodes"
            "${cfg.docker.workingDir}/user:/data/user"
            # Mount declaratively managed models from Nix store (via symlinker)
            "${cfg.docker.sharedModelsPath}/checkpoints:/data/models/checkpoints:ro"
            "${cfg.docker.sharedModelsPath}/loras:/data/models/loras:ro"
            "${cfg.docker.sharedModelsPath}/vae:/data/models/vae:ro"
            "${cfg.docker.sharedModelsPath}/clip_vision:/data/models/clip_vision:ro"
            "${cfg.docker.sharedModelsPath}/text_encoders:/data/models/text_encoders:ro"
            "${cfg.docker.sharedModelsPath}/diffusion_models:/data/models/diffusion_models:ro"
            "${cfg.docker.sharedModelsPath}/unet:/data/models/unet:ro"
            "${cfg.docker.sharedModelsPath}/controlnet:/data/models/controlnet:ro"
            "${cfg.docker.sharedModelsPath}/embeddings:/data/models/embeddings:ro"
            "${cfg.docker.sharedModelsPath}/upscale_models:/data/models/upscale_models:ro"
          ];
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
        };
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
                      if ! ${pkgs.docker}/bin/docker exec -u comfyui comfyui-docker [ -d /data/custom_nodes/${nodeName}/.git ]; then
                        echo "  → Cloning ${nodeName} from ${nodeUrl}..."
                        ${pkgs.docker}/bin/docker exec -u comfyui comfyui-docker bash -c "
                          cd /data/custom_nodes && \
                          git clone ${nodeUrl}
                        " && echo "  ✓ Successfully cloned ${nodeName}" || echo "  ✗ Failed to clone ${nodeName}"
                      else
                        echo "  → Updating ${nodeName}..."
                        ${pkgs.docker}/bin/docker exec -u comfyui comfyui-docker bash -c "
                          cd /data/custom_nodes/${nodeName} && \
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
                    if ! ${pkgs.docker}/bin/docker exec -u comfyui comfyui-docker [ -f /data/user/default/workflows/${filename} ]; then
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
                      ${pkgs.docker}/bin/docker cp /tmp/${filename} comfyui-docker:/data/user/default/workflows/${filename} && \
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
                  if ${pkgs.docker}/bin/docker exec -u comfyui comfyui-docker test -d /data/custom_nodes; then
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

                  if ${pkgs.docker}/bin/docker exec -u comfyui comfyui-docker [ -f /data/${model.destination} ]; then
                    echo "${filename} already exists, skipping..."
                  else
                    MODELS_DOWNLOADED=true
                    echo "Creating destination directory if needed..."
                    ${pkgs.docker}/bin/docker exec -u comfyui comfyui-docker mkdir -p /data/${dirname}
                    
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
                    ${pkgs.docker}/bin/docker cp /tmp/${filename} comfyui-docker:/data/${model.destination} && \
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
              if ${pkgs.docker}/bin/docker exec -u comfyui comfyui-docker test -d /data/models; then
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
