{
  lib,
  pkgs,
  config,
  configVars,
  ...
}:
{
  services.gotosocial.enable = lib.mkDefault true;
  services.gotosocial.settings.host = lib.mkDefault "gts.${configVars.domain}";
  services.gotosocial.settings.account-domain = lib.mkDefault configVars.domain;
  services.gotosocial.settings.port = 8087;
  services.gotosocial.settings.protocol = lib.mkDefault "https";
  services.gotosocial.settings.bind-address = "127.0.0.1";
  services.gotosocial.settings.application-name = lib.mkDefault "gotosocial";
  services.gotosocial.settings.db-type = lib.mkDefault "sqlite";
  services.gotosocial.settings.db-address = lib.mkDefault "/var/lib/gotosocial/database.sqlite";
  services.gotosocial.settings.storage-local-base-path = lib.mkDefault "/var/lib/gotosocial/storage";

  services.gotosocial.settings.landing-page-user = lib.mkDefault "";

  systemd.tmpfiles.rules = [
    "d /var/lib/gotosocial 755 gotosocial gotosocial"
  ];

  services.gotosocial.settings.instance-federation-spam-filter = lib.mkDefault true;
  services.gotosocial.settings.instance-inject-mastodon-version = lib.mkDefault true;

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  services.nginx.clientMaxBodySize = lib.mkDefault "40M";
  services.nginx.proxyCachePath."mygotosocial" = {
    enable = true;
    keysZoneName = "gotosocial_ap_public_responses";
    keysZoneSize = "10m";
    inactive = "1w";
  };
  services.nginx.virtualHosts."${config.services.gotosocial.settings.host}" = {
    enableACME = true;
    forceSSL = true;
    locations = {
      "~ /.well-known/(webfinger|host-meta)$" = {
        extraConfig = ''
          proxy_cache gotosocial_ap_public_responses;
          proxy_cache_background_update on;
          proxy_cache_key $scheme://$host$uri$is_args$query_string;
          proxy_cache_valid 200 10m;
          proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504 http_429;
          proxy_cache_lock on;
          add_header X-Cache-Status $upstream_cache_status;
        '';
        recommendedProxySettings = true;
        proxyPass = "http://127.0.0.1:8087";
      };
      "~ ^\/users\/(?:[a-z0-9_\.]+)\/main-key$" = {
        extraConfig = ''
          proxy_cache gotosocial_ap_public_responses;
          proxy_cache_background_update on;
          proxy_cache_key $scheme://$host$uri;
          proxy_cache_valid 200 604800s;
          proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504 http_429;
          proxy_cache_lock on;
          add_header X-Cache-Status $upstream_cache_status;
        '';
        recommendedProxySettings = true;
        proxyPass = "http://127.0.0.1:8087";
      };
      "/" = {
        recommendedProxySettings = true;
        proxyWebsockets = true;
        proxyPass = "http://127.0.0.1:8087";
        extraConfig = ''
          auth_basic off;
        '';
      };
      "/assets/" = {
        alias = "${config.services.gotosocial.settings.web-asset-base-dir}/";
        extraConfig = ''
          autoindex off;
          expires 5m;
          add_header Cache-Control "public";
        '';
      };
      "@fileserver" = {
        proxyWebsockets = true;
        recommendedProxySettings = true;
        proxyPass = "http://127.0.0.1:8087";
      };
      "/fileserver/" = {
        alias = "${config.services.gotosocial.settings.storage-local-base-path}/";
        tryFiles = "$uri @fileserver";
        extraConfig = ''
          autoindex off;
          expires 1w;
          add_header Cache-Control "private, immutable";
        '';
      };
    };
  };
  services.nginx.virtualHosts."gotosocialaccountdomain" =
    lib.mkIf
      (
        config.services.gotosocial.settings.account-domain != config.services.gotosocial.settings.host
        && config.services.gotosocial.settings.account-domain != ""
      )
      {
        serverName = config.services.gotosocial.settings.account-domain;
        enableACME = true;
        forceSSL = true;
        locations."/.well-known/webfinger".extraConfig = ''
          rewrite ^.*$ https://${config.services.gotosocial.settings.host}/.well-known/webfinger permanent;
        '';
        locations."/.well-known/host-meta".extraConfig = ''
          rewrite ^.*$ https://${config.services.gotosocial.settings.host}/.well-known/host-meta permanent;
        '';
        locations."/.well-known/nodeinfo".extraConfig = ''
          rewrite ^.*$ https://${config.services.gotosocial.settings.host}/.well-known/nodeinfo permanent;
        '';
      };
}
