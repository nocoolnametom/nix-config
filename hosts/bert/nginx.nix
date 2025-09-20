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
  # services.nginx.recommendedTlsSettings = true;
  services.nginx.recommendedOptimisation = true;
  services.nginx.recommendedGzipSettings = true;
  services.nginx.sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";
  #   services.nginx.commonHttpConfig = ''
  #     # Add HSTS header with preloading to HTTPS requests.
  #     # Adding this header to HTTP requests is discouraged
  #     map $scheme $hsts_header {
  #         https   "max-age=31536000; includeSubdomains; preload";
  #     }
  #     add_header Strict-Transport-Security $hsts_header;
  #
  #     # Enable CSP for your services.
  #     #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;
  #
  #     # Minimize information leaked to other domains
  #     add_header 'Referrer-Policy' 'origin-when-cross-origin';
  #
  #     # Disable embedding as a frame
  #     add_header X-Frame-Options DENY;
  #
  #     # Prevent injection of code in other mime types (XSS Attacks)
  #     add_header X-Content-Type-Options nosniff;
  #
  #     # Enable XSS protection of the browser.
  #     # May be unnecessary when CSP is configured properly (see above)
  #     add_header X-XSS-Protection "1; mode=block";
  #   '';
  services.nginx.virtualHosts =
    let
      homerConfig = import ./homer-blocks.nix {
        inherit
          lib
          config
          configVars
          pkgs
          ;
      };
      homerBlocks = homerConfig.homerBlocks;
      proxyPaths = homerConfig.proxyPaths;
      homeProxyPaths = homerConfig.homeProxyPaths;
      privateProxyPaths = homerConfig.privateProxyPaths;
    in
    {
      # Default page is a failure - prevent IP-only access unless specified below by IP address
      default = {
        default = true;
        serverName = "_";
        locations."/".return = "444";
        extraConfig = ''
          access_log off;
          log_not_found off;
        '';
      };
      # Mains
      "${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;

        locations = (homeProxyPaths false) // {
          "/.well-known".root = "/var/lib/acme/acme-challenge";
        };

        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "home.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        basicAuthFile = config.sops.secrets."bert-nginx-web-authfile".path;
        locations = (privateProxyPaths false) // {
          "/.well-known".root = "/var/lib/acme/acme-challenge";
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "localhost" = {
        serverAliases = [
          config.networking.hostName
          configVars.networking.subnets.bert.ip
        ];
        locations = proxyPaths true;
      };
      # Redirects
      "www.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            return = "301 https://${configVars.homeDomain}$request_uri";
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "house.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            return = "301 https://home.${configVars.domain}$request_uri";
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "request.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
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
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            return = "301 https://${configVars.networking.subdomains.ombi}.${configVars.domain}$request_uri";
          };
        };
      };

      # homeDomain Services
      "${configVars.networking.subdomains.authentik}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "https://${configVars.networking.subnets.cirdan.ip}:9443";
            proxyWebsockets = true;
          };
        };
      };
      # "${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}" = {
      #   enableACME = true;
      #   http2 = true;
      #   forceSSL = true;
      #   locations = {
      #     "/" = {
      #       proxyPass = "http://127.0.0.1:${builtins.toString configVars.networking.ports.tcp.kanidm}";
      #       proxyWebsockets = true;
      #     };
      #   };
      # };
      "${configVars.networking.subdomains.audiobookshelf}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.calibreweb}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.jellyfin}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.jellyfin}/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.budget}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.budget}/";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };

      "${configVars.networking.subdomains.budget-me}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.budget-me}/";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.budget-partner}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.budget-partner}/";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.budget-kid1}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.budget-kid1}/";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.budget-kid2}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.budget-kid2}/";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.podfetch}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.podfetch}/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.standardnotes-server}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.standardnotes-server}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.standardnotes-files}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.standardnotes-files}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.standardnotes}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.standardnotes}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.immich}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            recommendedProxySettings = true;
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.immich}";
            proxyWebsockets = true;
          };
        };
        extraConfig = ''
          auth_basic off;
          client_max_body_size 50000M;
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;
          send_timeout       600s;
        '';
      };
      "${configVars.networking.subdomains.immich-share}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.immich-share}/";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.kavita}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.navidrome}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.ombi}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/api".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/swagger".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.radarr}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString configVars.networking.ports.tcp.radarr}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.sickgear}.${configVars.homeDomain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };

      # domain Services
      "${configVars.networking.subdomains.comfyui}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        basicAuthFile = config.sops.secrets."bert-nginx-web-authfile".path;
        extraConfig = ''
          error_page 404 /${configVars.networking.subdomains.comfyui}.${configVars.domain}.404.html;
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
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
        http2 = true;
        forceSSL = true;
        basicAuthFile = config.sops.secrets."bert-nginx-web-authfile".path;
        extraConfig = ''
          error_page 404 /${configVars.networking.subdomains.comfyuimini}.${configVars.domain}.404.html;
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
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
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.flood}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.kavitan}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.nzbget}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString configVars.networking.ports.tcp.nzbget}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.phanpy}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations."/" = {
          root = pkgs.phanpy;
          extraConfig = ''
            auth_basic off;
          '';
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.radarr}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString configVars.networking.ports.tcp.radarr}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.sickgear}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.stash}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.stashvr}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.stashvr}";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_buffering off;
              auth_basic off;
            '';
          };
        };
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.stashvr-alias}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            return = "301 https://${configVars.networking.subdomains.stashvr}.${configVars.domain}$request_uri";
          };
        };
      };

      # deprecated domain services (should be on homeDomain already, just need to move over)
      "${configVars.networking.subdomains.audiobookshelf}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.calibreweb}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.jellyfin}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.jellyfin}/";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.standardnotes-server}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.standardnotes-server}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.standardnotes-files}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.standardnotes-files}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.standardnotes}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.standardnotes}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              proxy_cache off;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.immich}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations = {
          "/" = {
            proxyPass = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.immich}";
            proxyWebsockets = true;
            extraConfig = ''
              auth_basic off;
              client_max_body_size 50000M;
              proxy_read_timeout 600s;
              proxy_send_timeout 600s;
              send_timeout       600s;
            '';
          };
        };
      };
      "${configVars.networking.subdomains.kavita}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
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
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
      "${configVars.networking.subdomains.ombi}.${configVars.domain}" = {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations."/".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/api".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        locations."/swagger".proxyPass = "http://127.0.0.1:${builtins.toString config.services.ombi.port}";
        extraConfig = ''
          # Only use if cookies don't already have security flags
          proxy_cookie_path ~^/(.*)$ "/$1; secure; HTTPOnly; SameSite=strict";
        '';
      };
    };

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
        "${homeDomain}".email = email;
        "home.${domain}".email = email;
        # These are just redirects
        "${configVars.networking.subdomains.stashvr-alias}.${configVars.domain}".email = email;
        "www.${homeDomain}".email = email;
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
