{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.kavitan;
  settingsFormat = pkgs.formats.json { };
  appsettings = settingsFormat.generate "appsettings.json" (
    { TokenKey = "@TOKEN@"; } // cfg.settings
  );
in
{
  options.services.kavitan = {
    enable = lib.mkEnableOption "Kavitan reading server";

    user = lib.mkOption {
      type = lib.types.str;
      default = "kavitan";
      description = "User account under which Kavitan runs.";
    };

    package = lib.mkPackageOption pkgs "kavita" { };

    dataDir = lib.mkOption {
      default = "/var/lib/kavitan";
      type = lib.types.str;
      description = "The directory where Kavitan stores its state.";
    };

    tokenKeyFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        A file containing the TokenKey, a secret with at 512+ bits.
        It can be generated with `head -c 64 /dev/urandom | base64 --wrap=0`.
      '';
    };

    settings = lib.mkOption {
      default = { };
      description = ''
        Kavitan configuration options, as configured in {file}`appsettings.json`.
      '';
      type = lib.types.submodule {
        freeformType = settingsFormat.type;

        options = {
          Port = lib.mkOption {
            default = 5471;
            type = lib.types.port;
            description = "Port to bind to.";
          };

          IpAddresses = lib.mkOption {
            default = "0.0.0.0,::";
            type = lib.types.commas;
            description = ''
              IP Addresses to bind to. The default is to bind to all IPv4 and IPv6 addresses.
            '';
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.kavitan = {
      description = "Kavitan";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      preStart = ''
        install -m600 ${appsettings} ${lib.escapeShellArg cfg.dataDir}/config/appsettings.json
        ${pkgs.replace-secret}/bin/replace-secret '@TOKEN@' \
          ''${CREDENTIALS_DIRECTORY}/token \
          '${cfg.dataDir}/config/appsettings.json'
      '';
      serviceConfig = {
        WorkingDirectory = cfg.dataDir;
        LoadCredential = [ "token:${cfg.tokenKeyFile}" ];
        ExecStart = lib.getExe cfg.package;
        Restart = "always";
        User = cfg.user;
      };
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}'        0750 ${cfg.user} ${cfg.user} - -"
      "d '${cfg.dataDir}/config' 0750 ${cfg.user} ${cfg.user} - -"
    ];

    users = {
      users.${cfg.user} = {
        description = "kavitan service user";
        isSystemUser = true;
        group = cfg.user;
        home = cfg.dataDir;
      };
      groups.${cfg.user} = { };
    };
  };
}
