{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  comfyuiCfg = config.services.comfyui;
  cfg = comfyuiCfg.comfyuimini;

  # Determine output directory based on backend
  comfyuiOutputDir =
    if comfyuiCfg.useDocker then
      "${comfyuiCfg.docker.workingDir}/outputs"
    else
      "${comfyuiCfg.home}/.local/share/comfyui/output";

  # Default working directory
  defaultWorkingDir =
    if comfyuiCfg.useDocker then
      "/var/lib/comfyui-mini"
    else
      "${comfyuiCfg.home}/.local/share/comfyui-mini";
in
{
  options.services.comfyui.comfyuimini = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the ComfyUIMini frontend service.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall for the comfyui-mini service";
    };

    version = lib.mkOption {
      type = lib.types.str;
      default = "1.6.0";
      description = "Version of ComfyUIMini to use.";
    };

    workingDir = lib.mkOption {
      type = lib.types.str;
      default = defaultWorkingDir;
      description = "Working directory for ComfyUIMini installation and data.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = lib.mkIf cfg.openFirewall { allowedTCPPorts = [ 3000 ]; };
    systemd.services.comfyuimini = {
      description = "ComfyUIMini frontend service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Restart = "always";
        RestartSec = 5;
        Environment = [
          "PATH=${pkgs.gnused}/bin:${pkgs.nodejs}/bin:${pkgs.git}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin:${cfg.workingDir}/node_modules/.bin"
          "HOME=${cfg.workingDir}"
          "npm_config_cache=${cfg.workingDir}/.npm-cache"
        ];
      };

      preStart = ''
        set -euo pipefail

        mkdir -p ${cfg.workingDir}/repo
        mkdir -p ${cfg.workingDir}/.npm-cache
        chmod -R 777 ${cfg.workingDir}/.npm-cache
        cd ${cfg.workingDir}/repo

        if [ ! -d .git ]; then
          echo "Cloning ComfyUIMini..."
          git clone https://github.com/ImDarkTom/ComfyUIMini.git .
        fi

        git stash || true
        git pull --rebase || true
        git stash pop || true

        if [ ! -d node_modules/.bin ]; then
          echo "Installing dependencies..."
          npm ci
        fi

        if [ ! -d dist ]; then
          echo "Building project..."
          export PATH="$PWD/node_modules/.bin:$PATH"
          npm run build
        fi

        mkdir -p ./config
        if [ ! -f ./config/default.json ]; then
          echo "Creating config/default.json..."
          cp ./config/default.example.json ./config/default.json
          sed -i 's~"output_dir": ".*"~"output_dir": "${comfyuiOutputDir}"~' ./config/default.json
        fi
      '';

      script = ''
        cd ${cfg.workingDir}/repo
        exec npm start
      '';
    };
  };
}
