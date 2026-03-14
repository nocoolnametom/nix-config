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

    additionalFilesystems = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Additional filesystems/mount points to monitor beyond root.
        Can be devices (sdb), partitions (sdc1), or mount points (/mnt/data).
        Supports custom names using double underscores (e.g., "sdc1__Jellyfin Media").
        Maps to EXTRA_FILESYSTEMS environment variable.
      '';
      example = [
        "/mnt/data"
        "/home"
        "sdb1__Media Drive"
      ];
    };

    monitoredServices = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Systemd services to monitor status for.
        Supports glob patterns (e.g., "docker*", "beszel*").
        Maps to SERVICE_PATTERNS environment variable.
      '';
      example = [
        "nginx"
        "postgresql"
        "docker*"
      ];
    };

    enableSensors = mkOption {
      type = types.bool;
      default = true;
      description = "Enable hardware sensor monitoring (temperature, fans, etc.)";
    };
  };

  config = mkIf cfg.enable {
    # Install smartmontools for SMART disk monitoring
    environment.systemPackages = [ pkgs.smartmontools ];

    # Create static user for the agent (needed for persistence)
    users.users.beszel-agent = {
      isSystemUser = true;
      group = "beszel-agent";
      home = "/var/lib/beszel-agent";
      createHome = true;
      # Add to groups for monitoring capabilities
      extraGroups = [
        "disk"
      ] # S.M.A.R.T. disk monitoring (fallback if capabilities don't work)
      ++ lib.optional config.virtualisation.docker.enable "docker"; # Container monitoring
    };
    users.groups.beszel-agent = { };

    # Create a systemd service for the agent
    systemd.services.homelab-beszel-agent =
      let
        # Build the agent command with optional authentication
        agentScript = pkgs.writeShellScript "beszel-agent-start" ''
          # Set KEY as environment variable (without newlines)
          ${lib.optionalString (cfg.sshKeyFile != null) ''
            export KEY="$(cat ${cfg.sshKeyFile} | tr -d '\n')"
          ''}

          # Additional filesystem monitoring
          ${lib.optionalString (cfg.additionalFilesystems != [ ]) ''
            export EXTRA_FILESYSTEMS="${lib.concatStringsSep "," cfg.additionalFilesystems}"
          ''}

          # Systemd service monitoring
          ${lib.optionalString (cfg.monitoredServices != [ ]) ''
            export SERVICE_PATTERNS="${lib.concatStringsSep "," cfg.monitoredServices}"
          ''}

          # Hardware sensor monitoring
          ${lib.optionalString (!cfg.enableSensors) ''
            export SENSORS="false"
          ''}

          TOKEN_ARG=""
          ${lib.optionalString (cfg.tokenFile != null) ''
            if [ -f "${cfg.tokenFile}" ]; then
              TOKEN_ARG="--token $(cat ${cfg.tokenFile})"
            fi
          ''}
          exec ${homelab-beszel-agent}/bin/beszel-agent --listen :${toString cfg.port} \
            --url ${cfg.hubUrl} \
            $TOKEN_ARG
        '';
      in
      {
        description = "Homelab Beszel Monitoring Agent";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        # Ensure mount points are available before starting
        unitConfig = lib.mkIf (cfg.additionalFilesystems != [ ]) {
          RequiresMountsFor = lib.filter (fs: lib.hasPrefix "/" fs) cfg.additionalFilesystems;
        };

        serviceConfig = {
          Type = "simple";
          User = "beszel-agent";
          Group = "beszel-agent";
          WorkingDirectory = "/var/lib/beszel-agent";
          ExecStart = agentScript;
          Restart = "on-failure";
          RestartSec = "10s";

          # Make smartmontools available in PATH
          Environment = [ "PATH=${pkgs.smartmontools}/bin:/run/current-system/sw/bin" ];

          # SMART monitoring capabilities
          # CAP_SYS_RAWIO: Required for SATA/ATA via SG_IO
          # CAP_SYS_ADMIN: Required for NVMe admin passthrough
          AmbientCapabilities = [
            "CAP_SYS_RAWIO"
            "CAP_SYS_ADMIN"
          ];
          CapabilityBoundingSet = [
            "CAP_SYS_RAWIO"
            "CAP_SYS_ADMIN"
          ];

          # Security hardening
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          PrivateDevices = false; # Need access to disk devices for SMART monitoring

          # Need access to system info
          ProtectProc = "invisible";
          ProcSubset = "all";

          # Need access to /sys for hardware info
          ProtectKernelTunables = false;

          # D-Bus access for systemd service monitoring
          # Required for agent to communicate with systemd via D-Bus
          # Device access for SMART monitoring
          BindReadOnlyPaths = [
            "/run/dbus/system_bus_socket"
          ];
          DeviceAllow = [
            "/dev/nvme*" # NVMe drives for SMART
            "/dev/sd*" # SATA/SAS drives for SMART
            "char-usb_device" # USB devices
            "/dev/nvidia*" # NVIDIA GPU devices
            "/dev/dri/*" # AMD/Intel GPU devices (DRI)
          ];

          # Network access
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX" # Required for D-Bus socket communication
          ];
        };
      };

    # Open firewall for hub to connect to agent
    networking.firewall.allowedTCPPorts = mkIf config.networking.firewall.enable [
      cfg.port
    ];
  };
}
