{
  config,
  lib,
  pkgs,
  ...
}:

# Custom Beszel agent implementation for homelab
# Namespaced as "homelab-beszel-agent" to avoid conflicts with future official nixpkgs module
#
# MIGRATION PATH: When official nixpkgs module becomes available:
# 1. Replace services.homelab-beszel-agent with services.beszel.agent
# 2. Data location (/var/lib/beszel) should remain compatible
# 3. Remove this custom module
# 4. Update host imports to use official module

with lib;

let
  cfg = config.services.homelab-beszel-agent;

  # Fetch the latest Beszel agent binary
  homelab-beszel-agent = pkgs.stdenv.mkDerivation rec {
    pname = "beszel-agent";
    version = "0.18.4";

    src = pkgs.fetchurl {
      url = "https://github.com/henrygd/beszel/releases/download/v${version}/beszel-agent_linux_amd64.tar.gz";
      sha256 = "sha256-spjttayPRlN0aRtUr2wjmdWA2OvLUB/uURNw+nv5EPk=";
    };

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];

    unpackPhase = ''
      tar xzf $src
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp beszel-agent $out/bin/
      chmod +x $out/bin/beszel-agent
    '';

    meta = {
      description = "Lightweight server monitoring agent for Beszel";
      homepage = "https://github.com/henrygd/beszel";
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  options.services.homelab-beszel-agent = {
    enable = mkEnableOption "Homelab Beszel monitoring agent (custom implementation)";

    port = mkOption {
      type = types.port;
      default = 45876;
      description = "Port for the agent to listen on";
    };

    hubUrl = mkOption {
      type = types.str;
      description = "URL of the Beszel hub server";
      example = "http://estel:8090";
    };

    sshKeyFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to SSH public key file for authentication";
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing authentication token (e.g., universal token for self-registration)";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional arguments to pass to beszel-agent";
      example = [ "-v" ];
    };
  };

  config = mkIf cfg.enable {
    # Create a systemd service for the agent
    systemd.services.homelab-beszel-agent =
      let
        # Build the agent command with optional authentication
        agentScript = pkgs.writeShellScript "beszel-agent-start" ''
          TOKEN_ARG=""
          ${lib.optionalString (cfg.tokenFile != null) ''
            if [ -f "${cfg.tokenFile}" ]; then
              TOKEN_ARG="--token $(cat ${cfg.tokenFile})"
            fi
          ''}
          exec ${homelab-beszel-agent}/bin/beszel-agent --listen :${toString cfg.port} \
            ${lib.optionalString (cfg.sshKeyFile != null) "--key ${cfg.sshKeyFile}"} \
            $TOKEN_ARG
        '';
      in
      {
        description = "Homelab Beszel Monitoring Agent";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          ExecStart = agentScript;
          Restart = "on-failure";
          RestartSec = "10s";

          # Security hardening
          DynamicUser = true;
          StateDirectory = "beszel-agent"; # Persistent directory at /var/lib/beszel-agent
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;

          # Need access to system info
          ProtectProc = "invisible";
          ProcSubset = "all";

          # Need access to /sys for hardware info
          ProtectKernelTunables = false;

          # Network access
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
        };
      };

    # Open firewall for hub to connect to agent
    networking.firewall.allowedTCPPorts = mkIf config.networking.firewall.enable [
      cfg.port
    ];
  };
}
