{
  lib,
  config,
  pkgs,
  configVars,
  ...
}:

let
  # Detect which services are enabled on this system
  hasCups = config.services.printing.enable or false;
  hasDocker = config.virtualisation.docker.enable or false;
  hasNginx = config.services.nginx.enable or false;
  hasCaddy = config.services.caddy.enable or false;
  hasPostgresql = config.services.postgresql.enable or false;
  hasMysql = config.services.mysql.enable or false;
  hasRedis = config.services.redis.servers != { };
  hasElasticsearch = config.services.elasticsearch.enable or false;

  # Helper to create Python.d collector configs
  mkPythonCollector = name: conf: {
    "${name}" = {
      enable = true;
      config = conf;
    };
  };
in
{
  # Netdata collectors - automatically monitor services when they're enabled
  # This module should be imported on both parent and child nodes

  config = lib.mkIf config.services.netdata.enable {
    # Enable go.d plugin (modern collectors)
    services.netdata.configDir."go.d.conf" = pkgs.writeText "go.d.conf" ''
      enabled: yes
      default_run: yes
    '';

    # ===== CUPS (Printing) Monitoring =====
    services.netdata.configDir."go.d/cups.conf" = lib.mkIf hasCups (
      pkgs.writeText "cups.conf" ''
        jobs:
          - name: local
            url: http://127.0.0.1:631
            update_every: 5
      ''
    );

    # ===== Docker Monitoring =====
    services.netdata.configDir."go.d/docker.conf" = lib.mkIf hasDocker (
      pkgs.writeText "docker.conf" ''
        jobs:
          - name: local
            address: unix:///run/docker.sock
            update_every: 1
            # Collect per-container metrics
            collect_container_size: yes
      ''
    );

    # ===== Nginx Monitoring =====
    # Nginx needs stub_status enabled - we'll configure it separately
    services.netdata.configDir."go.d/nginx.conf" = lib.mkIf hasNginx (
      pkgs.writeText "nginx.conf" ''
        jobs:
          - name: local
            url: http://127.0.0.1:8080/nginx_status
            update_every: 1
      ''
    );

    # Enable nginx stub_status module
    services.nginx.statusPage = lib.mkIf hasNginx true;

    # ===== Caddy Monitoring =====
    services.netdata.configDir."go.d/prometheus.conf" = lib.mkIf hasCaddy (
      pkgs.writeText "prometheus-caddy.conf" ''
        jobs:
          - name: caddy
            url: http://127.0.0.1:2019/metrics
            update_every: 1
      ''
    );

    # ===== PostgreSQL Monitoring =====
    services.netdata.configDir."go.d/postgres.conf" = lib.mkIf hasPostgresql (
      pkgs.writeText "postgres.conf" ''
        jobs:
          - name: local
            dsn: 'postgres://netdata@/postgres?host=/run/postgresql&sslmode=disable'
            update_every: 5
            # Collect per-database metrics
            collect_databases:
              includes:
                - "*"
            # Collect table and index stats
            max_db_tables: 50
            max_db_indexes: 50
      ''
    );

    # Create PostgreSQL monitoring user with read-only access
    systemd.services.netdata-postgres-setup = lib.mkIf hasPostgresql {
      description = "Setup PostgreSQL monitoring user for Netdata";
      after = [ "postgresql.service" ];
      wants = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        RemainAfterExit = true;
      };
      script = ''
        ${config.services.postgresql.package}/bin/psql -d postgres <<SQL
          -- Create netdata user if it doesn't exist
          DO \$\$
          BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'netdata') THEN
              CREATE USER netdata;
            END IF;
          END
          \$\$;

          -- Grant necessary permissions for monitoring
          GRANT CONNECT ON DATABASE postgres TO netdata;
          GRANT pg_monitor TO netdata;
        SQL

        # Grant connect permission to all databases
        for db in $(${config.services.postgresql.package}/bin/psql -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres'"); do
          ${config.services.postgresql.package}/bin/psql -d "$db" -c "GRANT CONNECT ON DATABASE \"$db\" TO netdata;" || true
        done
      '';
    };

    # ===== MySQL/MariaDB Monitoring =====
    services.netdata.configDir."go.d/mysql.conf" = lib.mkIf hasMysql (
      pkgs.writeText "mysql.conf" ''
        jobs:
          - name: local
            dsn: netdata@unix(/run/mysqld/mysqld.sock)/
            update_every: 5
            # Collect detailed metrics
            my_cnf: /etc/my.cnf
      ''
    );

    # Create MySQL monitoring user
    systemd.services.netdata-mysql-setup = lib.mkIf hasMysql {
      description = "Setup MySQL monitoring user for Netdata";
      after = [ "mysql.service" ];
      wants = [ "mysql.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Wait for MySQL to be ready
        for i in {1..30}; do
          if ${config.services.mysql.package}/bin/mysqladmin ping -S /run/mysqld/mysqld.sock &>/dev/null; then
            break
          fi
          sleep 1
        done

        ${config.services.mysql.package}/bin/mysql -S /run/mysqld/mysqld.sock <<SQL
          -- Create netdata user if it doesn't exist
          CREATE USER IF NOT EXISTS 'netdata'@'localhost';

          -- Grant necessary permissions for monitoring
          GRANT USAGE, REPLICATION CLIENT, PROCESS ON *.* TO 'netdata'@'localhost';
          GRANT SELECT ON performance_schema.* TO 'netdata'@'localhost';
          FLUSH PRIVILEGES;
        SQL
      '';
    };

    # ===== Redis Monitoring =====
    services.netdata.configDir."go.d/redis.conf" = lib.mkIf hasRedis (
      pkgs.writeText "redis.conf" (
        let
          # Generate a job for each redis server instance
          redisJobs = lib.mapAttrsToList (
            name: serverConfig:
            let
              port = serverConfig.port or 6379;
              socket = serverConfig.unixSocket or null;
              address = if socket != null then "unix://${socket}" else "127.0.0.1:${toString port}";
            in
            ''
              - name: ${name}
                address: ${address}
                update_every: 1
            ''
          ) config.services.redis.servers;
        in
        ''
          jobs:
          ${lib.concatStrings redisJobs}
        ''
      )
    );

    # ===== Elasticsearch Monitoring =====
    services.netdata.configDir."go.d/elasticsearch.conf" = lib.mkIf hasElasticsearch (
      pkgs.writeText "elasticsearch.conf" ''
        jobs:
          - name: local
            url: http://127.0.0.1:9200
            update_every: 5
            # Cluster stats
            cluster_stats: yes
            # Node stats
            node_stats: yes
            # Index stats (can be resource intensive)
            collect_indices: yes
      ''
    );

    # ===== Group Membership for Socket Access =====
    # Add netdata user to necessary groups for accessing services
    users.users.netdata.extraGroups = lib.optional hasDocker "docker" ++ lib.optional hasRedis "redis";

    # ===== System Service Monitoring =====
    # Monitor systemd services
    services.netdata.config = {
      "plugin:apps" = {
        "update every" = 1;
      };

      "plugin:cgroups" = {
        "update every" = 1;
        "enable by default cgroups matching" = "*docker* *systemd*";
      };
    };

    # ===== Additional Python.d collectors =====
    # These use the legacy Python plugin but are still useful

    # Monitor fail2ban if enabled
    services.netdata.python.enable = lib.mkIf (config.services.fail2ban.enable or false) true;

    services.netdata.configDir."python.d/fail2ban.conf" =
      lib.mkIf (config.services.fail2ban.enable or false)
        (
          pkgs.writeText "fail2ban.conf" ''
            update_every: 10
            local:
              log_path: '/var/log/fail2ban.log'
          ''
        );
  };
}
