{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
{
  # Set up sops secret for basic auth file
  sops.secrets."bert-nginx-web-authfile".owner = config.services.nginx.user;

  services.nginx.enable = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.recommendedTlsSettings = true;
  services.nginx.recommendedOptimisation = true;
  services.nginx.recommendedGzipSettings = true;
  services.nginx.sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";
  services.nginx.commonHttpConfig = ''
    # Add HSTS header with preloading to HTTPS requests.
    # Adding this header to HTTP requests is discouraged
    map $scheme $hsts_header {
        https   "max-age=31536000; includeSubdomains; preload";
    }
    add_header Strict-Transport-Security $hsts_header;

    # Enable CSP for your services.
    #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

    # Minimize information leaked to other domains
    add_header 'Referrer-Policy' 'origin-when-cross-origin';

    # Disable embedding as a frame
    add_header X-Frame-Options DENY;

    # Prevent injection of code in other mime types (XSS Attacks)
    add_header X-Content-Type-Options nosniff;

    # Enable XSS protection of the browser.
    # May be unnecessary when CSP is configured properly (see above)
    add_header X-XSS-Protection "1; mode=block";

    # This might create errors
    proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
  '';
  services.nginx.virtualHosts =
    let
      proxyPaths = internal: {
        "/opds" = lib.attrsets.optionalAttrs config.services.calibre-server.enable {
          proxyPass = "http://127.0.0.1:8080/opds";
          extraConfig = ''
            auth_basic off;
          '';
        };
        "/get" = lib.attrsets.optionalAttrs config.services.calibre-server.enable {
          proxyPass = "http://127.0.0.1:8080/get/";
          extraConfig = ''
            auth_basic off;
          '';
        };
        "/music/" = lib.attrsets.optionalAttrs config.services.calibre-server.enable {
          proxyPass = "http://127.0.0.1:4533/music/";
          extraConfig = ''
            auth_basic off;
          '';
        };
        "/calibre/" = lib.attrsets.optionalAttrs config.services.calibre-web.enable {
          proxyPass = "http://127.0.0.1:${builtins.toString config.services.calibre-web.listen.port}/";
          extraConfig = ''
            proxy_set_header X-Scheme $scheme;
            proxy_set_header X-Script-Name /calibre;
            auth_basic off;
          '';
        };
        "/deluge/" = lib.attrsets.optionalAttrs config.services.deluge.web.enable {
          proxyPass = "http://127.0.0.1:${builtins.toString config.services.deluge.web.port}/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Deluge-Base /deluge;
          '';
        };
        "/flood/" = lib.attrsets.optionalAttrs config.services.flood.enable {
          proxyPass = "http://127.0.0.1:${builtins.toString config.services.flood.port}/";
          proxyWebsockets = true;
          extraConfig = ''
            auth_basic off;
            proxy_set_header X-Forwarded-Prefix /flood;
            proxy_buffering off;
            proxy_cache off;
            chunked_transfer_encoding off;
            rewrite ^/flood/(.*) /$1 break;
          '';
        };
        "/jellyfin/" = {
          proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:8096/jellyfin/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            auth_basic off;
          '';
        };
        "~ ^/nzbget($|./*)" = lib.attrsets.optionalAttrs config.services.nzbget.enable {
          proxyPass = "http://127.0.0.1:6789";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Prefix /nzbget;
            proxy_buffering off;
            rewrite ^/nzbget/(.*) /$1 break;
            auth_basic off;
          '';
        };
        "/stash/" = lib.attrsets.optionalAttrs config.services.stashapp.enable {
          proxyPass = "http://127.0.0.1:${builtins.toString config.services.stashapp.port}/";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header X-Forwarded-Prefix /stash;
            proxy_set_header X-Forwared-Port 80;
            proxy_buffering off;
            auth_basic off;
          '';
        };
        "/tv/" = lib.attrsets.optionalAttrs config.services.sickbeard.enable {
          proxyPass = "http://127.0.0.1:8081/tv/";
          extraConfig = ''
            auth_basic off;
          '';
        };
        "^~ /radarr" = lib.attrsets.optionalAttrs config.services.radarr.enable {
          proxyPass = "http://127.0.0.1:7878";
          extraConfig = ''
            auth_basic off;
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_redirect off;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $http_connection;
          '';
        };
        "^~ /radarr/api" = lib.attrsets.optionalAttrs config.services.radarr.enable {
          proxyPass = "http://127.0.0.1:7878";
          extraConfig = ''
            auth_basic off;
          '';
        };

        # Redirect all but OPDS routes to final slashes
        "~ ^/(calibre|deluge|flood|jellyfin|nzbget|stash|tv)$".return = "302 $scheme://$host$request_uri/";
        "/".root = pkgs.homer;
        "= /assets/config.yml".alias = pkgs.writeText "homerConfig.yml" (
          builtins.toJSON {
            title = "Dashboard";
            header = false;
            footer = false;
            connectivityCheck = false;
            columns = "auto";
            services = [
              {
                name = "Services";
                items =
                  [
                    {
                      name = "VSCode";
                      icon = "fas fa-globe";
                      url = "https://vscode.dev/+ms-vscode.remote-server/zg15993vmu";
                      target = "_blank";
                    }
                  ]
                  ++ (lib.lists.optionals config.services.calibre-web.enable [
                    {
                      name = "Calibre Books";
                      icon = "fas fa-book";
                      url = "/calibre/";
                      target = "_blank";
                    }
                  ])
                  ++ (lib.lists.optionals config.services.deluge.web.enable [
                    {
                      name = "Deluge Torrents";
                      icon = "fas fa-tasks";
                      url = "/deluge/";
                      target = "_blank";
                    }
                  ])
                  ++ (lib.lists.optionals config.services.flood.enable [
                    {
                      name = "Flood Torrents";
                      icon = "fas fa-tasks";
                      url = "/flood/";
                      target = "_blank";
                    }
                  ])
                  ++ ([
                    {
                      name = "Jellyfin Media Server";
                      icon = "fas fa-television";
                      url = "/jellyfin/";
                      target = "_blank";
                      type = "Emby";
                      apikey = "073c7a3eacfd4305835431b34a7ef5a6";
                      libraryType = "series";
                    }
                  ])
                  ++ (lib.lists.optionals config.services.ombi.enable [
                    {
                      name = "Ombi Requests";
                      icon = "fas fa-television";
                      url =
                        if internal then
                          "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.ombi.port}/"
                        else
                          "https://request.${configVars.domain}";
                      target = "_blank";
                    }
                  ])
                  ++ (lib.lists.optionals config.services.navidrome.enable [
                    {
                      name = "Music Streaming";
                      icon = "fas fa-music";
                      url = "/music/";
                      target = "_blank";
                    }
                  ])
                  ++ (lib.lists.optionals config.services.nzbget.enable [
                    {
                      name = "NZBGet";
                      icon = "fas fa-cloud-download";
                      url = "/nzbget/";
                      target = "_blank";
                    }
                  ])
                  ++ (lib.lists.optionals config.services.calibre-server.enable [
                    {
                      name = "OPDS Feed";
                      icon = "fas fa-rss-square";
                      url = "/opds";
                      target = "_blank";
                    }
                  ])
                  ++ [
                    {
                      name = "Stable Diffusion";
                      icon = "fas fa-gears";
                      url =
                        if internal then
                          "http://${configVars.networking.subnets.sauron.ip}:${builtins.toString configVars.networking.ports.tcp.invokeai}"
                        else
                          "https://stable.${configVars.domain}/";
                      target = "_blank";
                    }
                  ]
                  ++ (lib.lists.optionals config.services.stashapp.enable [
                    {
                      name = "Stash Data";
                      icon = "fas fa-lock";
                      url = "/stash/";
                      target = "_blank";
                    }
                  ])
                  ++ (lib.lists.optionals config.services.sickbeard.enable [
                    {
                      name = "Sickgear TV";
                      icon = "fas fa-download";
                      url = "/tv/";
                      target = "_blank";
                    }
                  ])
                  ++ (lib.lists.optionals config.services.radarr.enable [
                    {
                      name = "Radarr Movies";
                      icon = "fas fa-download";
                      url = "/radarr";
                      target = "_blank";
                    }
                  ]);
              }
            ];
          }
        );
      };
    in
    {
      "localhost" = {
        default = true;
        serverAliases = [
          config.networking.hostName
          configVars.networking.subnets.bert.ip
        ];
        locations = proxyPaths true;
      };
      "house.${configVars.domain}" = {
        serverAliases = [ "home.${configVars.domain}" ]; # This is the dynamic DNS subdomain
        enableACME = true;
        forceSSL = true;
        basicAuthFile = config.sops.secrets."bert-nginx-web-authfile".path;
        locations = (proxyPaths false) // {
          "/.well-known".root = "/var/lib/acme/acme-challenge";
        };
      };
      "requests.${configVars.domain}" = {
        serverAliases = [ "request.${configVars.domain}" ];
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/api".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/swagger".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
      };
      # "automatic.${configVars.domain}" = {
      #   enableACME = false;
      #   forceSSL = false;
      #   basicAuthFile = config.sops.secrets."bert-nginx-web-authfile".path;
      #   extraConfig = ''
      #     error_page 404 /automatic.${configVars.domain}.404.html;
      #   '';
      #   locations = {
      #     "/" = {
      #       proxyPass = "http://${configVars.networking.subnets.sauron.ip}:7860/";
      #       proxyWebsockets = true;
      #       extraConfig = ''
      #         proxy_buffering off;
      #         proxy_cache off;
      #         chunked_transfer_encoding off;
      #       '';
      #     };
      #     "/automatic.${configVars.domain}.404.html".extraConfig = ''
      #       root html
      #       allow all
      #       index easy.${configVars.domain}.404.html
      #       rewrite ^ $scheme://stable.${configVars.domain}$request_uri redirect;
      #     '';
      #   };
      # };
      "stable.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = config.sops.secrets."bert-nginx-web-authfile".path;
        extraConfig = ''
          error_page 404 /stable.${configVars.domain}.404.html;
        '';
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.sauron.ip}:${builtins.toString configVars.networking.ports.tcp.invokeai}/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
              proxy_cache off;
              chunked_transfer_encoding off;
            '';
          };
          # "/stable.${configVars.domain}.404.html".extraConfig = ''
          #   root html
          #   allow all
          #   index stable.${configVars.domain}.404.html
          #   rewrite ^ $scheme://easy.${configVars.domain}$request_uri redirect;
          # '';
        };
      };
      "library.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.kavita}/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; aio threads;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };
      };
    };
  security.acme.acceptTerms = true;
  security.acme.certs = {
    "house.${configVars.domain}".email = configVars.email.letsencrypt;
    "stable.${configVars.domain}".email = configVars.email.letsencrypt;
    "requests.${configVars.domain}".email = configVars.email.letsencrypt;
    # "automatic.${configVars.domain}".email = configVars.email.letsencrypt;
  };
}
