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
      homerBlocks = internal: {
        vscode = [
          {
            name = "VSCode";
            icon = "fas fa-globe";
            url = "https://vscode.dev/+ms-vscode.remote-server/zg15993vmu";
            target = "_blank";
          }
        ];
        deluge = lib.lists.optionals config.services.deluge.web.enable [
          {
            name = "Deluge Torrents";
            icon = "fas fa-tasks";
            url =
              if internal then
                "http://${configVars.networking.subnets.bert.ip}:${builtins.toString configVars.networking.ports.tcp.delugeweb}/"
              else
                "https://${configVars.networking.subdomains.deluge}.${configVars.domain}";
            target = "_blank";
          }
        ];
        flood = lib.lists.optionals config.services.flood.enable [
          {
            name = "Flood Torrents";
            icon = "fas fa-tasks";
            url =
              if internal then
                "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.flood.port}/"
              else
                "https://${configVars.networking.subdomains.flood}.${configVars.domain}";
            target = "_blank";
          }
        ];
        jellyfin = [
          {
            name = "Jellyfin Media Server";
            icon = "fas fa-television";
            url =
              if internal then
                "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.jellyfin}/"
              else
                "https://${configVars.networking.subdomains.jellyfin}.${configVars.homeDomain}";
            target = "_blank";
            type = "Emby";
            apikey = "073c7a3eacfd4305835431b34a7ef5a6";
            libraryType = "series";
          }
        ];
        ombi = lib.lists.optionals config.services.ombi.enable [
          {
            name = "Ombi Requests";
            icon = "fas fa-television";
            url =
              if internal then
                "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.ombi.port}/"
              else
                "https://${configVars.networking.subdomains.ombi}.${configVars.homeDomain}";
            target = "_blank";
          }
        ];
        navidrome = lib.lists.optionals config.services.navidrome.enable [
          {
            name = "Music Streaming";
            icon = "fas fa-music";
            url =
              if internal then
                "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.navidrome.settings.Port}/"
              else
                "https://${configVars.networking.subdomains.navidrome}.${configVars.homeDomain}";
            target = "_blank";
          }
        ];
        nzbget = lib.lists.optionals config.services.nzbget.enable [
          {
            name = "NZBGet";
            icon = "fas fa-cloud-download";
            url =
              if internal then
                "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.nzbget.port}/"
              else
                "https://${configVars.networking.subdomains.nzbget}.${configVars.domain}";
            target = "_blank";
          }
        ];
        calibreweb = [
          {
            name = "Books";
            icon = "fas fa-book";
            url =
              if internal then
                "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.calibreweb}"
              else
                "https://${configVars.networking.subdomains.calibreweb}.${configVars.homeDomain}/";
            target = "_blank";
          }
        ];
        kavita = [
          {
            name = "Comics";
            icon = "fas fa-book";
            url =
              if internal then
                "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.kavita}"
              else
                "https://${configVars.networking.subdomains.kavita}.${configVars.homeDomain}/";
            target = "_blank";
          }
        ];
        kavitan = [
          {
            name = "Manga";
            icon = "fas fa-book";
            url =
              if internal then
                "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.kavitan}"
              else
                "https://${configVars.networking.subdomains.kavitan}.${configVars.domain}/";
            target = "_blank";
          }
        ];
        audiobookshelf = [
          {
            name = "Audiobooks";
            icon = "fas fa-book";
            url =
              if internal then
                "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.audiobookshelf}"
              else
                "https://${configVars.networking.subdomains.audiobookshelf}.${configVars.homeDomain}/";
            target = "_blank";
          }
        ];
        comfyui = [
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
        ];
        comfyuimini = [
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
        ];
        stashapp = lib.lists.optionals config.services.stashapp.enable [
          {
            name = "Stash Data";
            icon = "fas fa-lock";
            url =
              if internal then
                "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.stashapp.port}/"
              else
                "https://${configVars.networking.subdomains.stash}.${configVars.domain}";
            target = "_blank";
          }
        ];
        phanpy = [
          {
            name = "Phanpy";
            icon = "fas fa-gears";
            url = "https://${configVars.networking.subdomains.phanpy}.${configVars.domain}/";
            target = "_blank";
          }
        ];
        sickgear = lib.lists.optionals config.services.sickbeard.enable [
          {
            name = "Sickgear TV";
            icon = "fas fa-download";
            url =
              if internal then
                "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.sickbeard.port}/"
              else
                "https://${configVars.networking.subdomains.sickgear}.${configVars.homeDomain}";
            target = "_blank";
          }
        ];
        radarr = lib.lists.optionals config.services.radarr.enable [
          {
            name = "Radarr Movies";
            icon = "fas fa-download";
            url =
              if internal then
                "http://${configVars.networking.subnets.bert.ip}:${builtins.toString config.services.radarr.port}/"
              else
                "https://${configVars.networking.subdomains.radarr}.${configVars.homeDomain}";
            target = "_blank";
          }
        ];
      };
      proxyPaths = internal: {
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
                  with homerBlocks internal;
                  vscode
                  ++ deluge
                  ++ flood
                  ++ jellyfin
                  ++ ombi
                  ++ navidrome
                  ++ nzbget
                  ++ calibreweb
                  ++ kavita
                  ++ kavitan
                  ++ audiobookshelf
                  ++ comfyui
                  ++ comfyuimini
                  ++ stashapp
                  ++ phanpy
                  ++ sickgear
                  ++ radarr;
              }
            ];
          }
        );
      };
      homeProxyPaths = internal: {
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
                  with homerBlocks internal;
                  jellyfin ++ ombi ++ navidrome ++ calibreweb ++ kavita ++ audiobookshelf ++ sickgear ++ radarr;
              }
            ];
          }
        );
      };
      privateProxyPaths = internal: {
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
                  with homerBlocks internal;
                  vscode ++ deluge ++ flood ++ nzbget ++ kavitan ++ comfyui ++ comfyuimini ++ stashapp ++ phanpy;
              }
            ];
          }
        );
      };
    in
    {
      # Mains
      "${configVars.homeDomain}" = {
        default = true;
        locations = (homeProxyPaths false) // {
          "/.well-known".root = "/var/lib/acme/acme-challenge";
        };
      };
      "home.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        basicAuthFile = config.sops.secrets."bert-nginx-web-authfile".path;
        locations = (privateProxyPaths false) // {
          "/.well-known".root = "/var/lib/acme/acme-challenge";
        };
      };
      "localhost" = {
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
      "request.${configVars.homeDomain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            return = "301 https://${configVars.networking.subdomains.ombi}.${configVars.homeDomain}$request_uri";
          };
        };
      };
      # Deprecated Redirect
      "request.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            return = "301 https://${configVars.networking.subdomains.ombi}.${configVars.domain}$request_uri";
          };
        };
      };

      # homeDomain Services
      "${configVars.networking.subdomains.audiobookshelf}.${configVars.homeDomain}" = {
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
      "${configVars.networking.subdomains.calibreweb}.${configVars.homeDomain}" = {
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
      "${configVars.networking.subdomains.jellyfin}.${configVars.homeDomain}" = {
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
      "${configVars.networking.subdomains.kavita}.${configVars.homeDomain}" = {
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
      "${configVars.networking.subdomains.navidrome}.${configVars.homeDomain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${builtins.toString config.services.navidrome.settings.Port}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_cache off;
            chunked_transfer_encoding off;
          '';
        };
      };
      "${configVars.networking.subdomains.ombi}.${configVars.homeDomain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/api".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/swagger".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
      };
      "${configVars.networking.subdomains.radarr}.${configVars.homeDomain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString config.services.radarr.port}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.sickgear}.${configVars.homeDomain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString config.services.sickbeard.port}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
      };

      # domain Services
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
      "${configVars.networking.subdomains.delugeweb}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString configVars.networking.ports.tcp.delugeweb}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.flood}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString config.services.flood.port}";
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
      "${configVars.networking.subdomains.nzbget}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString config.services.nzbget.port}";
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
      "${configVars.networking.subdomains.radarr}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString config.services.radarr.port}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.sickgear}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString config.services.sickbeard.port}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
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

      # deprecated domain services (should be on homeDomain already, just need to move over)
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
      "${configVars.networking.subdomains.ombi}.${configVars.domain}" = {
        enableACME = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/api".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/swagger".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
      };
    };
  security.acme.acceptTerms = true;
  security.acme.certs =
    let
      domain = configVars.domain;
      homeDomain = configVars.homeDomain;
      email = configVars.email.letsencrypt;
      subdomains = configVars.networking.subdomains;
      vhosts = config.services.nginx.virtualHosts;
      fqdnList = builtins.filter (fqdn: builtins.hasAttr fqdn vhosts) (
        (builtins.map (name: "${name}.${domain}") (builtins.attrValues subdomains))
        ++ (builtins.map (name: "${name}.${homeDomain}") (builtins.attrValues subdomains))
      );
    in
    (
      {
        # These subdomains are not present in the configVars.networking.subdomains list
        "${configVars.homeDomain}".email = email;
        "home.${domain}".email = email;
        # These are just redirects
        "house.${domain}".email = email;
        "request.${homeDomain}".email = email;
        "request.${domain}".email = email; # deprecated
      }
      // builtins.listToAttrs (
        # This filters the subdomains list to those currently present in the nginx config
        builtins.map (fqdn: {
          name = fqdn;
          value = {
            email = email;
          };
        }) fqdnList
      )
    );
}
