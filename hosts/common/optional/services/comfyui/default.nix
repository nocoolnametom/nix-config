{
  pkgs,
  config,
  inputs,
  lib,
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
            default = "ghcr.io/ai-dock/comfyui";
            description = "Docker image to use for ComfyUI";
          };

          version = mkOption {
            type = types.str;
            default = "latest-cuda";
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
                    description = "Destination path relative to /opt/ComfyUI inside container";
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
        };
      };
      default = { };
      description = "Docker-specific configuration options";
    };
  };

  config = mkMerge [
    # Common configuration for both backends
    {
      hardware.nvidia-container-toolkit.enable = mkDefault true;
      nixpkgs.config.cudaSupport = mkDefault true;
      nixpkgs.config.cudnnSupport = mkDefault true;

      nix.settings.trusted-substituters = [
        "https://ai.cachix.org"
        "https://cuda-maintainers.cachix.org"
      ];
      nix.settings.trusted-public-keys = [
        "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lU/mspIoz8hMvGvbbc="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];

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

    # Native ComfyUI configuration
    (mkIf (!cfg.useDocker) {
      services.comfyui.enable = mkDefault true;
      services.comfyui.host = mkDefault "0.0.0.0";
      networking.firewall.allowedTCPPorts = [ 8188 ];
      services.comfyui.models = mkDefault (
        pkgs.lib.attrByPath [ config.networking.hostName ] [ ] pkgs.my-sd-models.machineModels
      );
      services.comfyui.customNodes = mkDefault (
        pkgs.lib.attrByPath [ config.networking.hostName ] [ ] pkgs.my-sd-models.machineNodes
      );
    })

    # Docker ComfyUI configuration
    (mkIf cfg.useDocker {
      # Disable native service
      services.comfyui.enable = mkForce false;

      # Enable Docker backend
      virtualisation.arion.backend = mkForce "docker";
      virtualisation.docker.enable = mkForce true;
      virtualisation.docker.enableOnBoot = mkDefault true;

      networking.firewall.allowedTCPPorts = mkIf (cfg.docker.port != null) [ cfg.docker.port ];

      # Create necessary directories with proper permissions
      systemd.tmpfiles.rules = [
        "d ${cfg.docker.workingDir} 0775 1000 1111 - -"
        "d ${cfg.docker.workingDir}/models 0775 1000 1111 - -"
        "d ${cfg.docker.workingDir}/outputs 0775 1000 1111 - -"
        "d ${cfg.docker.workingDir}/inputs 0775 1000 1111 - -"
        "d ${cfg.docker.workingDir}/custom_nodes 0775 1000 1111 - -"
        "d ${cfg.docker.workingDir}/user 0775 1000 1111 - -"
        "d ${cfg.docker.workingDir}/user/default 0775 1000 1111 - -"
        "d ${cfg.docker.workingDir}/user/default/workflows 0775 1000 1111 - -"
        "d ${cfg.docker.workingDir}/user/default/temp 0775 1000 1111 - -"
      ];

      # Arion project for Docker ComfyUI
      virtualisation.arion.projects."comfyui-docker".settings = {
        services."comfyui-docker".service = {
          image = "${cfg.docker.image}:${cfg.docker.version}";
          container_name = "comfyui-docker";
          environment = cfg.docker.environment;
          env_file = lib.optionals (cfg.docker.additionalEnvironmentFile != null) [
            "${cfg.docker.additionalEnvironmentFile}"
          ];
          ports = [ "${builtins.toString cfg.docker.port}:8188" ];
          volumes = [
            "/nix/store:/nix/store:ro"
            "${cfg.docker.workingDir}/models:/opt/ComfyUI/models"
            "${cfg.docker.workingDir}/outputs:/opt/ComfyUI/output"
            "${cfg.docker.workingDir}/inputs:/opt/ComfyUI/input"
            "${cfg.docker.workingDir}/custom_nodes:/opt/ComfyUI/custom_nodes"
            "${cfg.docker.workingDir}/user:/opt/ComfyUI/user"
            "${cfg.docker.sharedModelsPath}/checkpoints:/opt/ComfyUI/models/checkpoints:ro"
            "${cfg.docker.sharedModelsPath}/loras:/opt/ComfyUI/models/loras:ro"
          ];
          restart = "unless-stopped";
          devices = [ "nvidia.com/gpu=all" ];
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
                nodeInstallScript = concatStringsSep "\n" (
                  map (
                    nodeUrl:
                    let
                      nodeName = builtins.baseNameOf nodeUrl;
                    in
                    ''
                      echo "Checking custom node: ${nodeName}..."
                      if ! ${pkgs.docker}/bin/docker exec comfyui-docker [ -d /opt/ComfyUI/custom_nodes/${nodeName}/.git ]; then
                        echo "Installing ${nodeName} from ${nodeUrl}..."
                        NODES_INSTALLED=true
                        ${pkgs.docker}/bin/docker exec comfyui-docker bash -c "
                          cd /opt/ComfyUI/custom_nodes && \
                          git clone ${nodeUrl} && \
                          cd ${nodeName} && \
                          if [ -f requirements.txt ]; then
                            echo 'Installing Python dependencies for ${nodeName}...'
                            pip install -r requirements.txt || echo 'Warning: Some dependencies failed to install'
                          fi
                        " || echo "Warning: Failed to install ${nodeName}"
                      else
                        echo "${nodeName} already installed, skipping..."
                      fi
                    ''
                  ) cfg.docker.customNodes
                );

                workflowInstallScript = concatStringsSep "\n" (
                  mapAttrsToList (filename: url: ''
                    echo "Checking workflow: ${filename}..."
                    if ! ${pkgs.docker}/bin/docker exec comfyui-docker [ -f /opt/ComfyUI/user/default/workflows/${filename} ]; then
                      echo "Downloading ${filename} from ${url}..."
                      WORKFLOWS_DOWNLOADED=true
                      
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
                      ${pkgs.docker}/bin/docker cp /tmp/${filename} comfyui-docker:/opt/ComfyUI/user/default/workflows/${filename} && \
                      rm /tmp/${filename} && \
                      echo "Successfully downloaded ${filename}" || \
                      echo "Warning: Failed to download ${filename}"
                    else
                      echo "${filename} already exists, skipping..."
                    fi
                  '') cfg.docker.workflows
                );
              in
              ''
                # Track whether anything new was installed
                NODES_INSTALLED=false
                WORKFLOWS_DOWNLOADED=false

                # Wait for container to be fully ready
                echo "Waiting for ComfyUI container to be ready..."
                for i in {1..30}; do
                  if ${pkgs.docker}/bin/docker exec comfyui-docker test -d /opt/ComfyUI/custom_nodes; then
                    echo "Container is ready!"
                    break
                  fi
                  echo "Waiting... ($i/30)"
                  sleep 2
                done

                # Install each declared custom node
                ${nodeInstallScript}

                # Download each declared workflow
                ${workflowInstallScript}

                # Restart ComfyUI to load new nodes (only if something new was installed)
                if [ "$NODES_INSTALLED" = "true" ]; then
                  echo "========================================"
                  echo "New nodes were installed!"
                  echo "Restarting ComfyUI to load new nodes..."
                  echo "========================================"
                  systemctl restart arion-comfyui-docker.service || true
                else
                  echo "All nodes already installed, no restart needed."
                fi

                echo "Custom node and workflow installation complete!"
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

                  if ${pkgs.docker}/bin/docker exec comfyui-docker [ -f /opt/ComfyUI/${model.destination} ]; then
                    echo "${filename} already exists, skipping..."
                  else
                    MODELS_DOWNLOADED=true
                    echo "Creating destination directory if needed..."
                    ${pkgs.docker}/bin/docker exec comfyui-docker mkdir -p /opt/ComfyUI/${dirname}
                    
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
                    ${pkgs.docker}/bin/docker cp /tmp/${filename} comfyui-docker:/opt/ComfyUI/${model.destination} && \
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
              if ${pkgs.docker}/bin/docker exec comfyui-docker test -d /opt/ComfyUI/models; then
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
