###############################################################################
#
#  TubeArchivist - arion containers with native Redis
#
#  Not packaged in nixpkgs, so it stays containerised. Elasticsearch stays a
#  container too: nixpkgs only ships 7.x and TA needs 8.x (an index created
#  by 8.x cannot be opened by 7.x). ES is TA's primary data store, not a
#  rebuildable cache - TA's Elasticsearch snapshots (Settings > Application >
#  Snapshots) are what move it to a new ES; they land in <stateDir>/es/snapshot
#  (ES path.repo).
#
#  Redis runs natively; TA keeps its app settings there. Containers reach it
#  at host.docker.internal, and the project network gets a fixed bridge name
#  so the firewall admits Redis traffic from this stack only, not the LAN.
#
#  forwardAuth: TubeArchivist logs users in from a username header
#  (TA_LOGIN_AUTH_MODE=forwardauth), set by the "tubearchivist" oauth2-proxy
#  instance on estel (oauth2-proxy.nix). Users are created on first login.
#  The LAN is trusted: anything on it that reaches the port directly could
#  send that header itself.
#
#  Secrets (nix-secrets): homelab/tubearchivist/{es-password,ta-password,
#  ta-token,mb-token}. ELASTIC_PASSWORD must match the value an existing index
#  was created with; ES only reads it when bootstrapping a fresh node.
#
###############################################################################

{
  config,
  configVars,
  inputs,
  lib,
  ...
}:
let
  cfg = config.services.tubearchivist;
  stateDir = cfg.stateDir;

  hostName = config.networking.hostName;
  hostIp = lib.attrByPath [ "networking" "subnets" hostName "ip" ] null configVars;
  publicUrl = "https://${configVars.networking.subdomains.tubearchivist}.${configVars.domain}";
  lanUrls = [
    "http://${hostName}.${configVars.homeLanDomain}:${toString cfg.port}"
  ]
  ++ lib.optional (hostIp != null) "http://${hostIp}:${toString cfg.port}";

  uid = toString cfg.uid;
  gid = toString cfg.gid;

  envFile = config.sops.templates."tubearchivist.env".path;

  bridge = "br-tubearch"; # interface names cap at 15 chars
  redisPort = 6380; # 6379 left free for a default instance
in
{
  imports = [ inputs.arion.nixosModules.arion ];

  options.services.tubearchivist = {
    mediaDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/tubearchivist/media";
      description = "Where downloaded videos are stored.";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/tubearchivist";
      description = ''
        Elasticsearch index and TA cache (including TA's backup zips).
        Keep it on SSD: ES is a database.
      '';
    };

    uid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = ''
        Numeric owner for downloaded media and the cache (TA's HOST_UID).
        Numeric because NixOS user uids are often auto-assigned, i.e. not
        known at evaluation time.
      '';
    };

    gid = lib.mkOption {
      type = lib.types.int;
      default = 100; # `users`
      description = "Numeric group for downloaded media and the cache (TA's HOST_GID).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = configVars.networking.ports.tcp.tubearchivist;
      description = "Host port the web UI is published on.";
    };

    forwardAuth = {
      enable = lib.mkEnableOption "login through a trusted proxy header (see the header comment)";
      usernameHeader = lib.mkOption {
        type = lib.types.str;
        # oauth2-proxy's X-Forwarded-Preferred-Username, in TA's naming
        default = "X_FORWARDED_PREFERRED_USERNAME";
        description = "Header TubeArchivist reads the username from.";
      };
    };
  };

  config = {
    sops.secrets."homelab/tubearchivist/es-password" = { };
    sops.secrets."homelab/tubearchivist/ta-password" = { };
    sops.secrets."homelab/tubearchivist/ta-token" = { };
    sops.secrets."homelab/tubearchivist/mb-token" = { };
    sops.templates."tubearchivist.env".content = ''
      ELASTIC_PASSWORD=${config.sops.placeholder."homelab/tubearchivist/es-password"}
      TA_PASSWORD=${config.sops.placeholder."homelab/tubearchivist/ta-password"}
      TA_TOKEN=${config.sops.placeholder."homelab/tubearchivist/ta-token"}
      MB_TOKEN=${config.sops.placeholder."homelab/tubearchivist/mb-token"}
    '';

    # Elasticsearch refuses to start below this.
    boot.kernel.sysctl."vm.max_map_count" = 262144;

    systemd.tmpfiles.rules = [
      "d ${cfg.mediaDir} 0755 ${uid} ${gid} -"
      "d ${stateDir} 0755 root root -"
      "d ${stateDir}/es 0770 1000 0 -" # elasticsearch image runs as 1000:0
      "d ${stateDir}/cache 0755 ${uid} ${gid} -"
    ];

    services.redis.servers.tubearchivist = {
      enable = true;
      bind = "0.0.0.0";
      port = redisPort;
      # The NixOS module enables protected mode, which resets connections from
      # non-loopback clients (the containers) when no password is set. Access
      # is scoped instead by the firewall rule below (stack bridge only).
      settings.protected-mode = "no";
    };
    networking.firewall.interfaces.${bridge}.allowedTCPPorts = [ redisPort ];

    virtualisation.arion.backend = "docker";
    services.arion-container-cleanup.projects.tubearchivist.containers = [
      "arion-tubearchivist-es"
      "arion-tubearchivist"
      "arion-tubearchivist-client"
    ];

    # If mediaDir sits on a nofail mount, never let downloads land on the
    # disk underneath it instead.
    systemd.services.arion-tubearchivist = {
      unitConfig.RequiresMountsFor = [
        cfg.mediaDir
        stateDir
      ];
      after = [ "redis-tubearchivist.service" ];
      requires = [ "redis-tubearchivist.service" ];
    };

    virtualisation.arion.projects.tubearchivist.settings.networks.default.driver_opts = {
      "com.docker.network.bridge.name" = bridge;
    };

    virtualisation.arion.projects.tubearchivist.settings.services = {
      es.service = {
        image = "elastic/elasticsearch:8.14.3";
        container_name = "arion-tubearchivist-es";
        labels."org.nix-config.managed-by" = "arion: change it in nix-config, not here";
        environment = {
          TZ = config.time.timeZone;
          ES_JAVA_OPTS = "-Xms512m -Xmx512m";
          "xpack.security.enabled" = "true";
          "discovery.type" = "single-node";
          "path.repo" = "/usr/share/elasticsearch/data/snapshot";
        };
        env_file = [ envFile ];
        volumes = [ "${stateDir}/es:/usr/share/elasticsearch/data" ];
        healthcheck.test = [
          "CMD-SHELL"
          "curl -s http://localhost:9200 >/dev/null || exit 1"
        ];
        restart = "on-failure:5";
      };
      es.out.service = {
        ulimits.memlock = {
          soft = -1;
          hard = -1;
        };
        security_opt = [
          "no-new-privileges:true"
          "seccomp:unconfined"
        ];
      };

      tubearchivist.service = {
        image = "bbilly1/tubearchivist:latest";
        container_name = "arion-tubearchivist";
        labels."org.nix-config.managed-by" = "arion: change it in nix-config, not here";
        ports = [ "${toString cfg.port}:8000" ];
        environment = {
          TZ = config.time.timeZone;
          HOST_UID = uid;
          HOST_GID = gid;
          ES_URL = "http://es:9200";
          REDIS_CON = "redis://host.docker.internal:${toString redisPort}";
          TA_USERNAME = configVars.username;
          TA_HOST = lib.concatStringsSep " " ([ publicUrl ] ++ lanUrls);
          TA_AUTO_UPDATE_YTDLP = "nightly";
          DISABLE_STATIC_AUTH = "1";
        }
        // lib.optionalAttrs cfg.forwardAuth.enable {
          TA_LOGIN_AUTH_MODE = "forwardauth";
          # A custom X- header is named without the HTTP_ prefix (TA 0.5.3+).
          TA_AUTH_PROXY_USERNAME_HEADER = cfg.forwardAuth.usernameHeader;
          TA_AUTH_PROXY_LOGOUT_URL = "${publicUrl}/oauth2/sign_out";
        };
        env_file = [ envFile ];
        volumes = [
          "${cfg.mediaDir}:/youtube"
          "${stateDir}/cache:/cache"
        ];
        healthcheck = {
          test = [
            "CMD-SHELL"
            "timeout 10s bash -c ':> /dev/tcp/127.0.0.1/8000' || exit 1"
          ];
          interval = "10s";
          timeout = "5s";
          retries = 3;
          start_period = "90s";
        };
        extra_hosts = [ "host.docker.internal:host-gateway" ];
        depends_on = [ "es" ];
        restart = "on-failure:5";
      };
      tubearchivist.out.service.security_opt = [ "no-new-privileges:true" ];

      # Members client: websocket to the TubeArchivist members service.
      tubearchivist-client.service = {
        image = "bbilly1/tubearchivist-client";
        container_name = "arion-tubearchivist-client";
        labels."org.nix-config.managed-by" = "arion: change it in nix-config, not here";
        environment = {
          TZ = config.time.timeZone;
          TA_URL = "http://tubearchivist:8000";
        };
        env_file = [ envFile ];
        depends_on = [ "tubearchivist" ];
        restart = "always";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
