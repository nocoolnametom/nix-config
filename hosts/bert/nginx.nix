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
        "/music/" = lib.attrsets.optionalAttrs config.services.calibre-server.enable {
          proxyPass = "http://127.0.0.1:4533/music/";
          extraConfig = ''
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
        "~ ^/(deluge|flood|jellyfin|nzbget|stash|tv)$".return = "302 $scheme://$host$request_uri/";
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
                          "https://${configVars.networking.subdomains.ombi}.${configVars.domain}";
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
                  ++ [
                    {
                      name = "Books";
                      icon = "fas fa-book";
                      url =
                        if internal then
                          "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.calibreweb}"
                        else
                          "https://${configVars.networking.subdomains.calibreweb}.${configVars.domain}/";
                      target = "_blank";
                    }
                  ]
                  ++ [
                    {
                      name = "Comics";
                      icon = "fas fa-book";
                      url =
                        if internal then
                          "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.kavita}"
                        else
                          "https://${configVars.networking.subdomains.kavita}.${configVars.domain}/";
                      target = "_blank";
                    }
                  ]
                  ++ [
                    {
                      name = "Kavita";
                      icon = "fas fa-book";
                      url =
                        if internal then
                          "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.kavitan}"
                        else
                          "https://${configVars.networking.subdomains.kavitan}.${configVars.domain}/";
                      target = "_blank";
                    }
                  ]
                  ++ [
                    {
                      name = "Audiobooks";
                      icon = "fas fa-book";
                      url =
                        if internal then
                          "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.audiobookshelf}"
                        else
                          "https://${configVars.networking.subdomains.audiobookshelf}.${configVars.domain}/";
                      target = "_blank";
                    }
                  ]
                  ++ [
                    {
                      name = "Stable Diffusion";
                      icon = "fas fa-gears";
                      url =
                        if internal then
                          "http://${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.comfyui}"
                        else
                          "https://${configVars.networking.subdomains.comfyui}.${configVars.domain}/";
                      target = "_blank";
                    }
                  ]
                  ++ [
                    {
                      name = "Stable Diffusion Mobile";
                      icon = "fas fa-gears";
                      url =
                        if internal then
                          "http://${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.comfyuimini}"
                        else
                          "https://${configVars.networking.subdomains.comfyuimini}.${configVars.domain}/";
                      target = "_blank";
                    }
                  ]
                  ++ [
                    {
                      name = "Phanpy";
                      icon = "fas fa-gears";
                      url = "https://${configVars.networking.subdomains.phanpy}.${configVars.domain}/";
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
      # Redirects
      "house.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            return = "301 https://home.${configVars.domain}$request_uri";
          };
        };
      };
      "request.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            return = "301 https://${configVars.networking.subdomains.ombi}.${configVars.domain}$request_uri";
          };
        };
      };

      # Canonicals
      "home.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = config.sops.secrets."bert-nginx-web-authfile".path;
        locations = (proxyPaths false) // {
          "/.well-known".root = "/var/lib/acme/acme-challenge";
        };
      };
      "${configVars.networking.subdomains.ombi}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/api".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/swagger".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
      };
      "${configVars.networking.subdomains.comfyui}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = config.sops.secrets."bert-nginx-web-authfile".path;
        extraConfig = ''
          error_page 404 /${configVars.networking.subdomains.comfyui}.${configVars.domain}.404.html;
        '';
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.comfyui}/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
              proxy_cache off;
              chunked_transfer_encoding off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.comfyuimini}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = config.sops.secrets."bert-nginx-web-authfile".path;
        extraConfig = ''
          error_page 404 /${configVars.networking.subdomains.comfyuimini}.${configVars.domain}.404.html;
        '';
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.comfyuimini}/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
              proxy_cache off;
              chunked_transfer_encoding off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.calibreweb}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.calibreweb}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.kavita}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.kavita}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.kavitan}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.kavitan}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.audiobookshelf}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.audiobookshelf}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.jellyfin}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:8096/jellyfin/";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.phanpy}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          root = pkgs.phanpy;
          extraConfig = ''
            auth_basic off;
          '';
        };
      };
      "${configVars.networking.subdomains.stash}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString config.services.stashapp.port}/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
              auth_basic off;
            '';
          };
        };
      };
    };
  security.acme.acceptTerms = true;
  security.acme.certs = {
    "home.${configVars.domain}".email = configVars.email.letsencrypt;
    # Redirects:
    "house.${configVars.domain}".email = configVars.email.letsencrypt;
    "request.${configVars.domain}".email = configVars.email.letsencrypt;
  } // (builtins.listToAttrs (
    builtins.map
      (name: {
        name = "${configVars.networking.subdomains.${name}}.${configVars.domain}";
        value = {
          email = configVars.email.letsencrypt;
        };
      })
      (builtins.attrNames configVars.networking.subdomains)
  ));
}
