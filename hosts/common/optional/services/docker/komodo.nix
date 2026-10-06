###############################################################################
#
#  Komodo - web UI for the host's Docker containers and compose stacks
#
#  Follows upstream's mongo.compose.yaml for Komodo v2, except that Periphery
#  (the agent that drives this host's Docker) runs natively:
#    - Core (web UI + API) and MongoDB: arion containers. nixpkgs has no Core
#      module and its komodo package ships the core binary without the web
#      frontend; nor is there a MongoDB server module.
#    - Periphery: the shared ../komodo-periphery.nix (native, from
#      nixpkgs-unstable), which other hosts import to appear in Komodo too.
#  In v2 Periphery connects out to Core and the two authenticate with key
#  pairs each generates on first start in <stateDir>/keys; there is no passkey.
#
#  Core can do anything Docker can on this host, so it is not published to the
#  Internet: estel's Caddy serves it over HTTPS (Kanidm only redirects to
#  https URLs) and refuses requests that do not come from the LAN.
#
#  Logins: Kanidm (OIDC client "komodo", server-admins only) or the local
#  admin account (KOMODO_INIT_ADMIN_USERNAME / homelab/komodo/init-admin-password),
#  which is the fallback if SSO is down. New users, including a first Kanidm
#  login, start disabled until the admin enables them: anyone on the LAN can
#  reach the sign-up form.
#
#  Secrets (nix-secrets): homelab/komodo/{db-password,jwt-secret,
#  webhook-secret,init-admin-password}, homelab/kanidm/oidc/komodo/client-secret.
#
###############################################################################

{
  config,
  configVars,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.komodo;
  publicUrl = "https://${configVars.networking.subdomains.komodo}.${configVars.homeDomain}";
  kanidmUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
  envFile = config.sops.templates."komodo.env".path;
  image = name: "ghcr.io/moghtech/${name}:2"; # major-version tag, as upstream ships it
  peripheryUser = config.services.komodo-periphery.user;
in
{
  imports = [
    inputs.arion.nixosModules.arion
    ../komodo-periphery.nix # this host's own agent
  ];

  options.services.komodo = {
    port = lib.mkOption {
      type = lib.types.port;
      default = configVars.networking.ports.tcp.komodo;
      description = "Host port Core's web UI is published on.";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/komodo";
      description = "MongoDB data, the Core/Periphery keys, Core's backups and Periphery's root.";
    };

    stacksDir = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.stateDir}/stacks";
      defaultText = lib.literalExpression ''"''${config.services.komodo.stateDir}/stacks"'';
      description = ''
        Where Periphery keeps the compose stacks it deploys. Periphery runs on
        the host, so compose files there use ordinary host paths.
      '';
    };
  };

  config = {
    sops.secrets."homelab/komodo/db-password" = { };
    sops.secrets."homelab/komodo/jwt-secret" = { };
    sops.secrets."homelab/komodo/webhook-secret" = { };
    sops.secrets."homelab/komodo/init-admin-password" = { };
    sops.secrets."komodo-oidc-client-secret".key = "homelab/kanidm/oidc/komodo/client-secret";
    sops.templates."komodo.env".content = ''
      MONGO_INITDB_ROOT_PASSWORD=${config.sops.placeholder."homelab/komodo/db-password"}
      KOMODO_DATABASE_PASSWORD=${config.sops.placeholder."homelab/komodo/db-password"}
      KOMODO_JWT_SECRET=${config.sops.placeholder."homelab/komodo/jwt-secret"}
      KOMODO_WEBHOOK_SECRET=${config.sops.placeholder."homelab/komodo/webhook-secret"}
      KOMODO_INIT_ADMIN_PASSWORD=${config.sops.placeholder."homelab/komodo/init-admin-password"}
      KOMODO_OIDC_CLIENT_SECRET=${config.sops.placeholder."komodo-oidc-client-secret"}
    '';
    # Read only when the containers start, so a changed secret restarts them.
    sops.templates."komodo.env".restartUnits = [ "arion-komodo.service" ];

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0751 root root -" # Periphery must reach keys/ and periphery/
      "d ${cfg.stateDir}/mongo 0750 root root -"
      # Core (root, in its container) writes core.key/core.pub here and
      # Periphery (its own user) writes periphery.key/periphery.pub.
      "d ${cfg.stateDir}/keys 0750 ${peripheryUser} root -"
      "d ${cfg.stateDir}/backups 0750 root root -"
      "d ${cfg.stateDir}/periphery 0750 ${peripheryUser} ${peripheryUser} -"
      "d ${cfg.stacksDir} 0750 ${peripheryUser} ${peripheryUser} -"
    ];

    virtualisation.arion.backend = "docker";
    services.arion-container-cleanup.projects.komodo.containers = [
      "arion-komodo-mongo"
      "arion-komodo-core"
    ];
    systemd.services.arion-komodo = {
      unitConfig.RequiresMountsFor = [
        cfg.stateDir
        cfg.stacksDir
      ];
    };

    virtualisation.arion.projects.komodo.settings.services = {
      mongo = {
        service = {
          image = "mongo:8";
          container_name = "arion-komodo-mongo";
          # Upstream's cache cap; MongoDB otherwise takes half the RAM.
          command = [
            "--quiet"
            "--wiredTigerCacheSizeGB"
            "0.25"
          ];
          labels = {
            "komodo.skip" = ""; # "Stop all containers" in Komodo leaves it alone
            "org.nix-config.managed-by" = "arion: change it in nix-config, not here";
          };
          environment.MONGO_INITDB_ROOT_USERNAME = "komodo";
          env_file = [ envFile ];
          volumes = [
            "${cfg.stateDir}/mongo/db:/data/db"
            "${cfg.stateDir}/mongo/configdb:/data/configdb"
          ];
          restart = "unless-stopped";
        };
      };

      core = {
        service = {
          image = image "komodo-core";
          container_name = "arion-komodo-core";
          labels."org.nix-config.managed-by" = "arion: change it in nix-config, not here";
          depends_on = [ "mongo" ];
          ports = [ "${toString cfg.port}:9120" ];
          environment = {
            TZ = config.time.timeZone;
            KOMODO_HOST = publicUrl;
            KOMODO_TITLE = "Komodo (${config.networking.hostName})";
            KOMODO_DATABASE_ADDRESS = "mongo:27017";
            KOMODO_DATABASE_USERNAME = "komodo";
            KOMODO_PERIPHERY_PUBLIC_KEY = "file:/config/keys/periphery.pub";
            KOMODO_FIRST_SERVER_NAME = config.networking.hostName;
            KOMODO_LOCAL_AUTH = "true";
            KOMODO_INIT_ADMIN_USERNAME = "admin";
            KOMODO_ENABLE_NEW_USERS = "false";
            KOMODO_OIDC_ENABLED = "true";
            KOMODO_OIDC_PROVIDER = "${kanidmUrl}/oauth2/openid/komodo";
            KOMODO_OIDC_CLIENT_ID = "komodo"; # matches the client in ../kanidm.nix
            KOMODO_OIDC_USE_FULL_EMAIL = "false";
          };
          env_file = [ envFile ];
          volumes = [
            "${cfg.stateDir}/keys:/config/keys"
            "${cfg.stateDir}/backups:/backups"
          ];
          restart = "unless-stopped";
        };
        # Upstream runs Core under an init process; arion has no typed option.
        out.service.init = true;
      };

    };

    # Core's own host: the agent talks to the published port locally, and
    # Core creates the first server from periphery.pub (no onboarding key).
    services.komodoAgent = {
      coreAddress = "ws://127.0.0.1:${toString cfg.port}";
      onboard = false;
    };
    services.komodo-periphery = {
      rootDirectory = "${cfg.stateDir}/periphery";
      stackDir = cfg.stacksDir;
      auth.privateKey = "file:${cfg.stateDir}/keys/periphery.key";
    };
    systemd.services.komodo-periphery = {
      after = [ "arion-komodo.service" ];
      wants = [ "arion-komodo.service" ];
    };

    # estel's Caddy proxies here over the LAN.
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
