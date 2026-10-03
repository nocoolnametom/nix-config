###############################################################################
#
#  TubeArchivist - arion transliteration of cirdan's Portainer stack
#
#  Not packaged in nixpkgs, so it stays containerised. Layout:
#    /silmaril/tubearchivist/media   <- 286 GB of downloads (@tubearchivist,
#                                       compression off like other video)
#    /var/lib/tubearchivist/{es,cache}  <- NVMe, persisted. ES is a
#                                       database; keep it off the btrfs HDDs.
#    /var/lib/redis-tubearchivist      <- native Redis (persisted); TA keeps
#                                       its app settings in Redis.
#
#  Elasticsearch stays a container: nixpkgs only ships 7.x and TA needs 8.x
#  (the migrated index was created by 8.14.3, which 7.x cannot open).
#  Redis runs natively. Containers reach it at host.docker.internal; the
#  project network gets a fixed bridge name so the firewall can admit Redis
#  traffic from this stack only, not from the LAN.
#
#  Secrets (nix-secrets): homelab/tubearchivist/{es-password,ta-password,
#  ta-token,mb-token}. ELASTIC_PASSWORD must match the value the migrated
#  index was created with; ES only reads it when bootstrapping a fresh node.
#
###############################################################################

{
  config,
  configVars,
  inputs,
  ...
}:
let
  mediaDir = "/silmaril/tubearchivist/media";
  stateDir = "/var/lib/tubearchivist";
  port = configVars.networking.ports.tcp.tubearchivist;
  publicUrl = "https://${configVars.networking.subdomains.tubearchivist}.${configVars.domain}";

  # tdoggett:users, so downloaded media is owned by a real user on the host.
  uid = toString config.users.users.${configVars.username}.uid;
  gid = toString config.users.groups.users.gid;

  envFile = config.sops.templates."tubearchivist.env".path;

  bridge = "br-tubearch"; # interface names cap at 15 chars
  redisPort = 6380; # 6379 left free for a default instance
in
{
  imports = [ inputs.arion.nixosModules.arion ];

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
    "d ${mediaDir} 0755 ${uid} ${gid} -"
    "d ${stateDir} 0755 root root -"
    "d ${stateDir}/es 0770 1000 0 -" # elasticsearch image runs as 1000:0
    "d ${stateDir}/cache 0755 ${uid} ${gid} -"
  ];

  services.redis.servers.tubearchivist = {
    enable = true;
    # Explicit bind (not null) keeps Redis out of protected mode, which would
    # refuse the containers; the firewall rule below is what scopes access.
    bind = "0.0.0.0";
    port = redisPort;
  };
  networking.firewall.interfaces.${bridge}.allowedTCPPorts = [ redisPort ];

  virtualisation.arion.backend = "docker";
  services.arion-container-cleanup.projects.tubearchivist = { };

  # The pool mount is nofail; without this a missing @tubearchivist would let
  # downloads land on the ephemeral root instead.
  systemd.services.arion-tubearchivist = {
    unitConfig.RequiresMountsFor = [ mediaDir ];
    after = [ "redis-tubearchivist.service" ];
    requires = [ "redis-tubearchivist.service" ];
  };

  virtualisation.arion.projects.tubearchivist.settings.networks.default.driver_opts = {
    "com.docker.network.bridge.name" = bridge;
  };

  virtualisation.arion.projects.tubearchivist.settings.services = {
    es.service = {
      image = "elastic/elasticsearch:8.14.3";
      container_name = "TubeArchivist-ES";
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
      container_name = "TubeArchivist";
      ports = [ "${toString port}:8000" ];
      environment = {
        TZ = config.time.timeZone;
        HOST_UID = uid;
        HOST_GID = gid;
        ES_URL = "http://es:9200";
        REDIS_CON = "redis://host.docker.internal:${toString redisPort}";
        TA_USERNAME = configVars.username;
        TA_HOST = "${publicUrl} http://feanor.${configVars.homeLanDomain}:${toString port} http://${configVars.networking.subnets.feanor.ip}:${toString port}";
        TA_AUTO_UPDATE_YTDLP = "nightly";
        DISABLE_STATIC_AUTH = "1";
      };
      env_file = [ envFile ];
      volumes = [
        "${mediaDir}:/youtube"
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
      container_name = "tubearchivist-client";
      environment = {
        TZ = config.time.timeZone;
        TA_URL = "http://tubearchivist:8000";
      };
      env_file = [ envFile ];
      depends_on = [ "tubearchivist" ];
      restart = "always";
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
