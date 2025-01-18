{
  lib,
  pkgs,
  config,
  configVars,
  ...
}:
with lib;
let
  cfg = config.services.mygotosocial;
in
{
  # Declare what settings a user of this "hello.nix" module CAN SET.
  options.services.mygotosocial = {
    enable = mkEnableOption "mygotosocial service";
    useNginx = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to set up Nginx for the service.
      '';
    };
    rootUserMe = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to set me as the root user.
      '';
    };
    host = mkOption {
      default = "";
      type = types.str;
      description = ''
        The actual display domain of the service (gts.example.com)
      '';
    };
    account-domain = mkOption {
      default = "";
      type = types.str;
      description = ''
        The nice domain of the service (example.com)
      '';
    };
    port = mkOption {
      type = types.port;
      default = 8087;
      description = ''
        TCP port the service should listen on.
      '';
    };
    storage-local-base-path = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/gotosocial/storage";
      description = ''
        Where to store local files
      '';
    };
  };

  config = mkIf cfg.enable {
    services.gotosocial.enable = true;
    services.gotosocial.settings.host = cfg.host;
    services.gotosocial.settings.account-domain = mkIf (cfg.account-domain != "") cfg.account-domain;
    services.gotosocial.settings.port = cfg.port;
    services.gotosocial.settings.protocol = mkDefault "https";
    services.gotosocial.settings.bind-address = mkDefault "127.0.0.1";
    services.gotosocial.settings.storage-local-base-path = cfg.storage-local-base-path;

    services.gotosocial.settings.landing-page-user = mkIf cfg.rootUserMe "tom";

    systemd.tmpfiles.rules = [
      "d ${cfg.storage-local-base-path} 755 gotosocial gotosocial"
    ];

    environment.persistence."${configVars.persistFolder}".directories = [
      cfg.storage-local-base-path
    ];

    services.gotosocial.settings.instance-federation-spam-filter = mkDefault true;
    services.gotosocial.settings.instance-inject-mastodon-version = mkDefault true;

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    security.acme.certs = mkIf cfg.useNginx {
      "${cfg.host}".email = configVars.email.letsencrypt;
    };

    services.nginx = mkIf cfg.useNginx {
      clientMaxBodySize = mkDefault "40M";
      # proxyCachePath."mygotosocial" {
      #   enable = true;
      #   keyZoneName = "gotosocial_ap_public_responses";
      #   keysZoneSize = "10m";
      #   inactive = "1w";
      # };
      virtualHosts."${cfg.host}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          # "~ /.well-known/(webfinger|host-meta)$" = {
          #   extraConfig = ''
          #     proxy_set_header Host $host;
          #     proxy_set_header X-Forwarded-For $remote_addr;
          #     proxy_set_header X-Forwarded-Proto $scheme;

          #     proxy_cache gotosocial_ap_public_responses;
          #     proxy_cache_background_update on;
          #     proxy_cache_key $scheme://$host$uri$is_args$query_string;
          #     proxy_cache_valid 200 10m;
          #     proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504 http_429;
          #     proxy_cache_lock on;
          #     add_header X-Cache-Status $upstream_cache_status;
          #   '';
          #   proxyPass = "http://${config.services.gotosocial.settings.bind-address}:${toString cfg.port}";
          # };
          # "~ ^\/users\/(?:[a-z0-9_\.]+)\/main-key$" = {
          #   extraConfig = ''
          #     proxy_set_header Host $host;
          #     proxy_set_header X-Forwarded-For $remote_addr;
          #     proxy_set_header X-Forwarded-Proto $scheme;

          #     proxy_cache gotosocial_ap_public_responses;
          #     proxy_cache_background_update on;
          #     proxy_cache_key $scheme://$host$uri;
          #     proxy_cache_valid 200 604800s;
          #     proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504 http_429;
          #     proxy_cache_lock on;
          #     add_header X-Cache-Status $upstream_cache_status;
          #   '';
          #   proxyPass = "http://${config.services.gotosocial.settings.bind-address}:${toString cfg.port}";
          # };
          "/" = {
            recommendedProxySettings = true;
            proxyWebsockets = true;
            proxyPass = "http://${config.services.gotosocial.settings.bind-address}:${toString cfg.port}";
            extraConfig = ''
              auth_basic off;
            '';
          };
          # "/assets/" =  {
          #   alias = "${config.services.gotosocial.settings.web-asset-base-dir}/";
          #   extraConfig = ''
          #     autoindex off;
          #     expires 5m;
          #     add_header Cache-Control "public";
          #   '';
          # };
          # "@fileserver" = {
          #   proxyPass = "http://localhost:${cfg.port}";
          #   extraConfig = ''
          #     proxy_set_header Host $host;
          #     proxy_set_header Upgrade $http_upgrade;
          #     proxy_set_header Connection "upgrade";
          #     proxy_set_header X-Forwarded-For $remote_addr;
          #     proxy_set_header X-Forwarded-Proto $scheme;
          #   '';
          # };
          # "/fileserver/" = {
          #   alias = "${cfg.storage-local-base-path}/";
          #   tryFiles = "$uri @fileserver";
          #   extraConfig = ''
          #     autoindex off;
          #     expires 1w;
          #     add_header Cache-Control "private, immutable";
          #   '';
          # };
        };
      };
      virtualHosts."${cfg.account-domain}" = mkIf (cfg.account-domain != cfg.host) {
        enableACME = true;
        forceSSL = true;
        locations."/.well-known/webfinger".extraConfig = ''
          rewrite ^.*$ https://${cfg.host}/.well-known/webfinger permanent;
        '';
        locations."/.well-known/host-meta".extraConfig = ''
          rewrite ^.*$ https://${cfg.host}/.well-known/host-meta permanent;
        '';
        locations."/.well-known/nodeinfo".extraConfig = ''
          rewrite ^.*$ https://${cfg.host}/.well-known/nodeinfo permanent;
        '';
      };
    };
  };
}
