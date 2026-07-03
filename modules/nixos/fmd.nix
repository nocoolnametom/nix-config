{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.fmd;
  settingsFormat = pkgs.formats.yaml { };
  hasToken = cfg.registrationTokenFile != null;
  settingsWithToken =
    cfg.settings
    // lib.optionalAttrs hasToken {
      RegistrationToken = "@REGISTRATION_TOKEN@";
    };
  configFile = settingsFormat.generate "fmd-config.yml" settingsWithToken;
in
{
  options.services.fmd = {
    enable = lib.mkEnableOption "fmd-server (FindMyDevice)";

    package = lib.mkPackageOption pkgs "fmd-server" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = "fmd";
      description = "User account under which fmd-server runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "fmd";
      description = "Group under which fmd-server runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/fmd";
      description = ''
        Home directory for the fmd service. Holds the generated config
        file, the SQLite database, and any logs.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to open {option}`services.fmd.settings.PortInsecure` in
        the firewall.
      '';
    };

    registrationTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the fmd-server RegistrationToken. When
        set, its contents are interpolated into the generated config at
        service start via a systemd credential, keeping the secret out of
        the Nix store. Set this on private instances to prevent open
        registration.
      '';
    };

    settings = lib.mkOption {
      default = { };
      description = ''
        fmd-server configuration, rendered as {file}`config.yml`. See
        <https://gitlab.com/fmd-foss/fmd-server/-/blob/master/config.example.yml>
        for the full list of keys.
      '';
      type = lib.types.submodule {
        freeformType = settingsFormat.type;

        options = {
          PortInsecure = lib.mkOption {
            type = lib.types.str;
            default = "8080";
            description = ''
              Plain-HTTP listening port. Set to an empty string to
              disable. fmd-server accepts either a bare port ("8080") or
              a full address ("[::1]:8080").
            '';
          };

          PortSecure = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              HTTPS listening port. Defaults to empty because TLS is
              expected to terminate at a reverse proxy. Set
              {option}`settings.ServerCrt` and {option}`settings.ServerKey`
              alongside this if you want fmd-server to terminate TLS.
            '';
          };

          DatabaseDir = lib.mkOption {
            type = lib.types.str;
            default = "${cfg.dataDir}/db/";
            defaultText = lib.literalExpression ''"''${cfg.dataDir}/db/"'';
            description = "Directory where fmd-server stores its SQLite database.";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # StateDirectory= is used to provision cfg.dataDir with the correct
    # ownership. It only accepts paths under /var/lib/, so if dataDir is
    # customised elsewhere, callers must provision it themselves.
    assertions = [
      {
        assertion = lib.hasPrefix "/var/lib/" cfg.dataDir;
        message = "services.fmd.dataDir must live under /var/lib/ (got: ${cfg.dataDir}) so systemd's StateDirectory= can manage it.";
      }
    ];

    systemd.services.fmd = {
      description = "fmd-server (FindMyDevice)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      preStart = ''
        install -m600 ${configFile} '${cfg.dataDir}/config.yml'
      ''
      + lib.optionalString hasToken ''
        ${pkgs.replace-secret}/bin/replace-secret '@REGISTRATION_TOKEN@' \
          "$CREDENTIALS_DIRECTORY/registration-token" \
          '${cfg.dataDir}/config.yml'
      '';
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        StateDirectory = lib.removePrefix "/var/lib/" cfg.dataDir;
        StateDirectoryMode = "0750";
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${lib.getExe cfg.package} serve --config ${cfg.dataDir}/config.yml";
        Restart = "always";
        LoadCredential = lib.optional hasToken "registration-token:${toString cfg.registrationTokenFile}";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf (
      cfg.openFirewall && cfg.settings.PortInsecure != ""
    ) [ (lib.toInt cfg.settings.PortInsecure) ];

    users.users.${cfg.user} = {
      description = "fmd-server service user";
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
    };
    users.groups.${cfg.group} = { };
  };
}
