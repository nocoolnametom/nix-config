{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.stash.vr-helper;
  stashCfg = config.services.stash;

  # Sanitize host name for systemd service naming
  sanitizeName = name: builtins.replaceStrings [ "." ":" "/" "@" " " ] [ "-" "-" "-" "-" "-" ] name;

  # Host type definition
  hostType = types.submodule (
    { name, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to enable this stash-vr instance.";
        };

        stashUrl = mkOption {
          type = types.str;
          description = "Full URL to the stash instance (e.g., 'http://192.168.1.10:9998' or 'https://stash.example.com')";
        };

        port = mkOption {
          type = types.port;
          default = 9666;
          description = "Port for this stash-vr instance to listen on. Must be unique across all instances.";
        };

        forceHttps = mkOption {
          type = types.bool;
          default = false;
          description = "Force HTTPS when generating URLs for the VR interface.";
        };

        dataDir = mkOption {
          type = types.path;
          default = "${cfg.dataDir}/${name}";
          defaultText = literalExpression ''"''${config.services.stash.vr-helper.dataDir}/''${name}"'';
          description = "Data directory for this stash-vr instance.";
        };
      };
    }
  );

  # Get all enabled hosts
  enabledHosts = filterAttrs (n: v: v.enable) cfg.hosts;

  # Create a systemd service for each enabled host
  mkHostService = name: hostCfg: {
    name = "stash-vr-${sanitizeName name}";
    value = {
      enable = mkDefault true;
      description = "Stash-vr daemon for ${name}";
      after = [
        "network.target"
        "stash.service"
      ];
      wants = [ "stash.service" ];
      wantedBy = [ "multi-user.target" ];
      restartIfChanged = mkDefault true;

      environment = {
        STASH_GRAPHQL_URL = "${hostCfg.stashUrl}/graphql";
        CONFIG_PATH = hostCfg.dataDir;
        LISTEN_ADDRESS = ":${toString hostCfg.port}";
        FAVORITE_TAG = cfg.favoriteTag;
        EXCLUDE_SORT_NAME = cfg.excludeSortName;
        HEATMAP_HEIGHT_PX = toString cfg.heatmapHeightPx;
        FORCE_HTTPS = if hostCfg.forceHttps then "true" else "false";
      };

      script = "${cfg.package}/bin/stash-vr";

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = hostCfg.dataDir;
        EnvironmentFile = mkIf (cfg.apiEnvironmentVariableFile != "") [ cfg.apiEnvironmentVariableFile ];

        # Security hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ hostCfg.dataDir ];
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        CapabilityBoundingSet = [ "" ];
        AmbientCapabilities = [ "" ];
        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        PrivateUsers = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        ProtectProc = "invisible";
        ProcSubset = "pid";
        RestrictNamespaces = true;
        UMask = "0077";
      };
    };
  };

  # Tmpfiles rules for all host data directories
  mkTmpfilesRule = name: hostCfg: "d ${hostCfg.dataDir} 0750 ${cfg.user} ${cfg.group} -";

in
{
  options.services.stash.vr-helper = {
    enable = mkEnableOption "Enable Stash VR helper service";

    user = mkOption {
      type = types.str;
      default = "stash-vr";
      description = "User account under which stash-vr instances run.";
    };

    group = mkOption {
      type = types.str;
      default = "stash-vr";
      description = "Group under which stash-vr instances run.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/stash-vr";
      description = "Base path where stash-vr stores its configuration and data files. Each host gets a subdirectory.";
    };

    hosts = mkOption {
      type = types.attrsOf hostType;
      default = { };
      description = "Stash-vr instances to run. Each key becomes the instance name.";
      example = literalExpression ''
        {
          local = {
            stashUrl = "http://192.168.1.10:9998";
            port = 9666;
            forceHttps = false;
          };
          external = {
            stashUrl = "https://stash.example.com";
            port = 9667;
            forceHttps = true;
          };
        }
      '';
    };

    apiEnvironmentVariableFile = mkOption {
      type = types.str;
      default = "";
      description = "Optional file containing stash API key behind a key of STASH_API_KEY. Shared across all instances.";
    };

    package = mkOption {
      type = types.package;
      default = pkgs.stash-vr;
      defaultText = literalExpression "pkgs.stash-vr";
      description = "Stash-vr package to use.";
    };

    favoriteTag = mkOption {
      type = types.str;
      default = "FAVORITE";
      description = "Tag name to mark scenes as favorites. Shared across all instances.";
    };

    excludeSortName = mkOption {
      type = types.str;
      default = "hidden";
      description = "Sort name used to exclude scenes from appearing in the VR interface. Shared across all instances.";
    };

    heatmapHeightPx = mkOption {
      type = types.int;
      default = 0;
      description = "Height in pixels for the heatmap display. Set to 0 to disable. Shared across all instances.";
    };
  };

  config = mkIf (stashCfg.enable && cfg.enable) {
    # Validation: at least one host must be defined
    assertions = [
      {
        assertion = cfg.hosts != { };
        message = "services.stash.vr-helper.hosts must define at least one host when enabled.";
      }
      {
        assertion =
          let
            ports = mapAttrsToList (n: v: v.port) enabledHosts;
            uniquePorts = unique ports;
          in
          length ports == length uniquePorts;
        message = "services.stash.vr-helper.hosts must have unique ports across all enabled instances.";
      }
    ];

    # Create user and group for stash-vr
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      description = "Stash VR helper service user";
    };

    users.groups.${cfg.group} = { };

    # Create systemd services for each enabled host
    systemd.services = listToAttrs (mapAttrsToList mkHostService enabledHosts);

    # Create data directories for each host
    systemd.tmpfiles.rules = mapAttrsToList mkTmpfilesRule enabledHosts;
  };
}
