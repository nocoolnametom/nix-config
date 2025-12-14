{ lib, pkgs, config, ... }:
let
  cfg = config.services.mormonsites;
  phpEnv = pkgs.php.buildEnv {
    extensions = { enabled, all }:
      enabled ++ (with pkgs.php.extensions; [ mysqli pdo_mysql ]);
    extraConfig = ''
      mysqli.default_socket = /run/mysqld/mysqld.sock
      pdo_mysql.default_socket = /run/mysqld/mysqld.sock
    '';
  };

  mkSeedService = name: inst:
    let
      prefix = inst.envPrefix;
      sharePath = "${inst.package}/share/${inst.shareName}";
      seedVar = "${prefix}_DB_PASSWORD";
      seedScript = pkgs.writeShellScript "mormonsite-seed-${name}" ''
        set -euo pipefail

        db="${inst.database.name}"
        dbUser="${inst.database.user}"
        dbPass="$(printenv ${seedVar} || true)"

        passClause=""
        if [ -n "$dbPass" ]; then
          escapedPass=$(printf "%s" "$dbPass" | sed "s/'/\047\047/g")
          passClause=" IDENTIFIED BY '$escapedPass'"
        fi

        mysql --protocol=socket -N -e "CREATE DATABASE IF NOT EXISTS \`$db\`;"
        mysql --protocol=socket -N -e "CREATE USER IF NOT EXISTS '$dbUser'@'localhost'$passClause;"
        mysql --protocol=socket -N -e "GRANT SELECT ON \`$db\`.* TO '$dbUser'@'localhost'; FLUSH PRIVILEGES;"

        existing=$(mysql --protocol=socket -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$db' AND table_name='lds_scriptures_books';")
        if [ "$existing" -eq 0 ]; then
          mysql --protocol=socket "$db" < ${sharePath}/data.sql
        fi
      '';
    in {
      description = "Seed MySQL data for Mormon site (${name})";
      after = [ "mysql.service" ];
      requires = [ "mysql.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.mariadb ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ExecStart = seedScript;
        EnvironmentFile = lib.optional (inst.database.passwordFile != null) inst.database.passwordFile;
      };
    };

  mkAppService = name: inst:
    let
      prefix = inst.envPrefix;
      sharePath = "${inst.package}/share/${inst.shareName}";
    in {
      description = "Mormon site PHP server (${name})";
      after = [ "mysql.service" "mormonsite-${name}-seed.service" "network.target" ];
      wants = [ "mysql.service" "mormonsite-${name}-seed.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        WorkingDirectory = "${sharePath}";
        ExecStart = ''${phpEnv}/bin/php -S ${inst.listenAddress}:${toString inst.port} -t ${sharePath}/public ${sharePath}/router.php'';
        EnvironmentFile = lib.optional (inst.database.passwordFile != null) inst.database.passwordFile;
      };
      environment = {
        "${prefix}_DB_NAME" = inst.database.name;
        "${prefix}_DB_USER" = inst.database.user;
        "${prefix}_DB_HOST" = inst.database.host;
      };
    };
in
{
  options.services.mormonsites = {
    enable = lib.mkEnableOption "Mormon sites PHP scripture browser";

    defaultEnvPrefix = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional default env var prefix (e.g., MORMONCANON) used by instances when not set explicitly.";
    };

    defaultShareName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional default share subdirectory name under the package (e.g., mormoncanon, mormonquotes).";
    };

    defaultListenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Default listen address for instances unless overridden.";
    };

    defaultOpenFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Default whether instances open firewall ports unless overridden.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "mormonsites";
      description = "System user that runs the application services.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "mormonsites";
      description = "System group for the application services.";
    };

    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable this instance.";
          };
          port = lib.mkOption {
            type = lib.types.port;
            description = "TCP port the PHP built-in server should listen on.";
          };

          listenAddress = lib.mkOption {
            type = lib.types.str;
            default = cfg.defaultListenAddress;
            description = "Listen address for the PHP built-in server.";
          };

          envPrefix = lib.mkOption {
            type = lib.types.str;
            default = lib.mkDefault (if cfg.defaultEnvPrefix != null then cfg.defaultEnvPrefix else "MORMONCANON");
            description = "Environment variable prefix used for DB settings (e.g., MORMONCANON -> MORMONCANON_DB_NAME).";
          };

          openFirewall = lib.mkOption {
            type = lib.types.bool;
            default = cfg.defaultOpenFirewall;
            description = "Whether to open the firewall for the service port.";
          };

          database = lib.mkOption {
            type = lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "MySQL database name.";
                };
                user = lib.mkOption {
                  type = lib.types.str;
                  default = "${name}";
                  description = "MySQL user used by the application.";
                };
                host = lib.mkOption {
                  type = lib.types.str;
                  default = "127.0.0.1";
                  description = "MySQL host.";
                };
                passwordFile = lib.mkOption {
                  type = lib.types.nullOr lib.types.path;
                  default = null;
                  description = "Optional file containing MORMONCANON_DB_PASSWORD=... for the application user.";
                };
              };
            };
            description = "Database configuration.";
          };

          package = lib.mkOption {
            type = lib.types.package;
            description = "Package to run for this instance (use mormoncanon/mormonquotes/journalofdiscourses).";
          };

          shareName = lib.mkOption {
            type = lib.types.str;
            default = lib.mkDefault (if cfg.defaultShareName != null then cfg.defaultShareName else "mormoncanon");
            description = "Subdirectory under the package's share/ containing the app (e.g., mormoncanon, mormonquotes, journalofdiscourses).";
          };
        };
      }));
      default = { };
      description = "Instances of Mormon sites to run (supports multiple DBs/sites with different packages).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.instances != { }) && (lib.length (lib.filter (inst: inst.enable) (lib.attrValues cfg.instances)) > 0);
        message = "services.mormonsites.instances must define at least one enabled site.";
      }
    ];

    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
    };

    services.mysql.enable = lib.mkDefault true;

    systemd.services =
      (lib.mapAttrs'
        (n: inst: lib.optionalAttrs inst.enable (lib.nameValuePair "mormonsite-${n}-seed" (mkSeedService n inst)))
        cfg.instances)
      //
      (lib.mapAttrs'
        (n: inst: lib.optionalAttrs inst.enable (lib.nameValuePair "mormonsite-${n}" (mkAppService n inst)))
        cfg.instances);

    networking.firewall.allowedTCPPorts = lib.mkIf (cfg.instances != { }) (
      lib.concatMap (inst: if inst.enable then lib.optional inst.openFirewall inst.port else [ ]) (lib.attrValues cfg.instances)
    );
  };
}
