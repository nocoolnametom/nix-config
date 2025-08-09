{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.autoDeploy;
in
{
  options.services.autoDeploy = {
    enable = mkEnableOption "Enable automatic deployment on git push";

    gitRepoPath = mkOption {
      type = types.str;
      default = "/var/lib/nix-config";
      description = "Path where the git repository should be cloned";
    };

    deployUser = mkOption {
      type = types.str;
      default = "nixdeploy";
      description = "User that will run the deployment process";
    };

    flakeUri = mkOption {
      type = types.str;
      default = "github:nocoolnametom/nix-config";
      description = "Flake URI for the configuration repository";
    };

    sshKeys = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "SSH public keys authorized to trigger deployments";
    };

    deployTargets = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of deploy-rs node names to deploy to (empty = deploy all)";
      example = [ "bert" "smeagol" ];
    };

    webhookPort = mkOption {
      type = types.port;
      default = 8123;
      description = "Port for webhook receiver service";
    };

    webhookSecret = mkOption {
      type = types.str;
      description = "Webhook secret for authentication";
    };
  };

  config = mkIf cfg.enable {
    # Create deploy user
    users.users.${cfg.deployUser} = {
      isSystemUser = true;
      group = cfg.deployUser;
      home = cfg.gitRepoPath;
      createHome = true;
      openssh.authorizedKeys.keys = cfg.sshKeys;
      shell = pkgs.bash;
    };

    users.groups.${cfg.deployUser} = {};

    # Allow deploy user to manage systemd and nixos-rebuild
    security.sudo.rules = [
      {
        users = [ cfg.deployUser ];
        commands = [
          {
            command = "${pkgs.systemd}/bin/systemctl";
            options = [ "NOPASSWD" ];
          }
          {
            command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # Install required packages
    environment.systemPackages = with pkgs; [
      git
      deploy-rs
      nixos-rebuild
    ];

    # Webhook receiver service
    systemd.services.auto-deploy-webhook = {
      description = "Auto Deploy Webhook Receiver";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScript "webhook-receiver" ''
          set -e
          
          # Simple webhook receiver
          ${pkgs.netcat}/bin/nc -l -p ${toString cfg.webhookPort} -c '
            read request
            echo "HTTP/1.1 200 OK"
            echo "Content-Length: 2"
            echo ""
            echo "OK"
            
            # Trigger deployment in background
            systemctl start auto-deploy-git.service &
          '
        ''}";
        Restart = "always";
        User = cfg.deployUser;
        Group = cfg.deployUser;
      };
    };

    # Git-based deployment service
    systemd.services.auto-deploy-git = {
      description = "Auto Deploy from Git";
      
      serviceConfig = {
        Type = "oneshot";
        User = cfg.deployUser;
        Group = cfg.deployUser;
        WorkingDirectory = cfg.gitRepoPath;
      };
      
      script = ''
        set -e
        
        echo "[Auto-Deploy] Starting deployment process..."
        
        # Clone or update repository
        if [ ! -d "${cfg.gitRepoPath}/.git" ]; then
          echo "[Auto-Deploy] Cloning repository..."
          ${pkgs.git}/bin/git clone ${cfg.flakeUri} ${cfg.gitRepoPath}
          cd ${cfg.gitRepoPath}
        else
          echo "[Auto-Deploy] Updating repository..."
          cd ${cfg.gitRepoPath}
          ${pkgs.git}/bin/git fetch origin
          ${pkgs.git}/bin/git reset --hard origin/main
        fi
        
        # Update flake inputs
        echo "[Auto-Deploy] Updating flake inputs..."
        ${pkgs.nix}/bin/nix flake update --accept-flake-config
        
        # Run deploy-rs
        echo "[Auto-Deploy] Running deployment..."
        ${if cfg.deployTargets == [] then
          "${pkgs.deploy-rs}/bin/deploy --flake . --skip-checks"
        else
          lib.concatMapStringsSep "\n" (target: 
            "${pkgs.deploy-rs}/bin/deploy --flake . .${target} --skip-checks"
          ) cfg.deployTargets
        }
        
        echo "[Auto-Deploy] Deployment completed successfully!"
      '';
      
      environment = {
        NIX_CONFIG = "experimental-features = nix-command flakes";
      };
    };

    # Open firewall for webhook
    networking.firewall.allowedTCPPorts = [ cfg.webhookPort ];

    # Create git post-receive hook script for local git repos
    environment.etc."auto-deploy-post-receive-hook" = {
      text = ''
        #!/bin/bash
        set -e
        
        echo "[Git Hook] Received push, triggering auto-deployment..."
        
        # Trigger the deployment service
        systemctl start auto-deploy-git.service
        
        echo "[Git Hook] Auto-deployment triggered!"
      '';
      mode = "0755";
    };
  };
}