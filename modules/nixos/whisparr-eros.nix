###############################################################################
#
#  Whisparr-Eros (Whisparr V3) service module
#
#  Mirrors nixpkgs' servarr modules -- specifically `radarr`, which Eros is
#  derived from, rather than `whisparr`/`sonarr` which the V2 line follows.
#  Kept out of tree because nixpkgs only packages the V2 `whisparr`.
#
###############################################################################

{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.whisparr-eros;

  # Local copies of the helpers in nixpkgs'
  # nixos/modules/services/misc/servarr/settings-options.nix. Inlined rather
  # than imported: that file is a nixpkgs-internal path with no stability
  # guarantee, and a rename there would break every `nix flake update`.
  mkServarrSettingsOptions =
    port:
    lib.mkOption {
      type = lib.types.submodule {
        freeformType = (pkgs.formats.ini { }).type;
        options = {
          update = {
            mechanism = lib.mkOption {
              type =
                with lib.types;
                nullOr (enum [
                  "external"
                  "builtIn"
                  "script"
                ]);
              description = "Which update mechanism to use.";
              default = "external";
            };
            automatically = lib.mkOption {
              type = lib.types.bool;
              description = "Automatically download and install updates.";
              default = false;
            };
          };
          server = {
            port = lib.mkOption {
              type = lib.types.port;
              description = "Port number.";
              default = port;
            };
          };
          log = {
            analyticsEnabled = lib.mkOption {
              type = lib.types.bool;
              description = "Send anonymous usage data.";
              default = false;
            };
          };
        };
      };
      example = lib.options.literalExpression ''
        {
          update.mechanism = "internal";
          server = {
            urlbase = "localhost";
            port = ${toString port};
            bindaddress = "*";
          };
        }
      '';
      default = { };
      description = ''
        Attribute set of arbitrary config options.
        Please consult the documentation at the
        [wiki](https://wiki.servarr.com/useful-tools#using-environment-variables-for-config).

        WARNING: this configuration is stored in the world-readable Nix store!
        For secrets use [](#opt-services.whisparr-eros.environmentFiles).
      '';
    };

  # Eros still identifies itself as "Whisparr" internally, so its config
  # sections are `Whisparr:Server:Port` etc., read via .AddEnvironmentVariables().
  mkServarrSettingsEnvVars =
    name: settings:
    lib.pipe settings [
      (lib.mapAttrsRecursive (
        path: value:
        lib.optionalAttrs (value != null) {
          name = lib.toUpper "${name}__${lib.concatStringsSep "__" path}";
          value = toString (if lib.isBool value then lib.boolToString value else value);
        }
      ))
      (lib.collect (x: lib.isString x.name or false && lib.isString x.value or false))
      lib.listToAttrs
    ];
in
{
  options = {
    services.whisparr-eros = {
      enable = lib.mkEnableOption "Whisparr-Eros, an adult scene collection manager";

      package = lib.mkPackageOption pkgs "whisparr-eros" { };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/whisparr-eros";
        description = ''
          The directory where Whisparr-Eros stores its data files. It is created
          before the service starts, owned by {option}`services.whisparr-eros.user`.
        '';
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open ports in the firewall for the Whisparr-Eros web interface.";
      };

      # Upstream's default, which collides with the V2 `whisparr` service: a
      # host running both must move one of them via `settings.server.port`.
      settings = mkServarrSettingsOptions 6969;

      environmentFiles = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ ];
        description = ''
          Environment files to pass secret configuration values. Each line must
          follow the `WHISPARR__SECTION__KEY=value` pattern.
        '';
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "whisparr-eros";
        description = "User account under which Whisparr-Eros runs.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "whisparr-eros";
        description = "Group under which Whisparr-Eros runs.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings."10-whisparr-eros".${cfg.dataDir}.d = {
      inherit (cfg) user group;
      mode = "0700";
    };

    systemd.services.whisparr-eros = {
      description = "Whisparr-Eros";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = mkServarrSettingsEnvVars "WHISPARR" cfg.settings;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        EnvironmentFile = cfg.environmentFiles;
        ExecStart = "${lib.getExe cfg.package} -nobrowser -data='${cfg.dataDir}'";
        Restart = "on-failure";

        # Hardening (matching nixpkgs' radarr module)
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        ProtectHome = true;
        ProtectClock = true;
        ProtectKernelLogs = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateUsers = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        UMask = "0022";
        ProtectHostname = true;
        ProtectProc = "invisible";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@debug"
          "~@mount"
          "@chown"
        ];
      };
      unitConfig.RequiresMountsFor = [ cfg.dataDir ];
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.settings.server.port ];
    };

    users.users = lib.mkIf (cfg.user == "whisparr-eros") {
      whisparr-eros = {
        group = cfg.group;
        home = cfg.dataDir;
        isSystemUser = true;
      };
    };

    users.groups = lib.mkIf (cfg.group == "whisparr-eros") {
      whisparr-eros = { };
    };
  };
}
