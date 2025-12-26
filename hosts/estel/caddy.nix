{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
let
  # Authentik proxy host (change here if Authentik moves to a different machine)
  authentikHost = "cirdan";

  # Simple service definitions - just the essentials!
  # These will be automatically converted to both regular and punch-through hosts
  #
  # Keys:
  #   host: The actual machine hosting the service
  #   service: Service name (used for subdomain and port lookup)
  #   domain: Either "homeDomain" or "domain"
  #   proxy: (optional) Set to "authentik" if regular domain should route through Authentik
  #
  # When proxy = "authentik":
  #   - Regular domain: service.domain → caddy → authentik → host:service (SSO authentication)
  #   - Punch domain: service.punch.domain → caddy → host:service (basic auth, bypasses Authentik for monitoring)
  #
  # When proxy is not set:
  #   - Both regular and punch domains go directly to service
  #   - Punch domain adds basic auth for monitoring
  simpleServices = [
    # Services on homeDomain
    {
      host = "estel";
      service = "audiobookshelf";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "budget";
      domain = "homeDomain";
    }
    {
      host = "cirdan";
      service = "calibreweb";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "hedgedoc";
      domain = "homeDomain";
    }
    {
      host = "cirdan";
      service = "immich";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "immich-share";
      domain = "homeDomain";
    }
    {
      host = "cirdan";
      service = "jellyfin";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "karakeep";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "kavita";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "mealie";
      domain = "homeDomain";
    }
    {
      host = "cirdan";
      service = "nas";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "navidrome";
      domain = "homeDomain";
      proxy = "authentik";
    }
    {
      host = "estel";
      service = "ombi";
      domain = "homeDomain";
      proxy = "authentik";
    }
    {
      host = "estel";
      service = "paperless";
      domain = "homeDomain";
    }
    {
      host = "cirdan";
      service = "podfetch";
      domain = "homeDomain";
    }
    {
      host = "cirdan";
      service = "portainer";
      domain = "homeDomain";
    }

    # Services on domain
    {
      host = "smeagol";
      service = "archerstash";
      domain = "domain";
    }
    {
      host = "smeagol";
      service = "archerstashvr";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "sdurin";
      service = "stash";
      domain = "domain";
    }
    {
      host = "durin";
      service = "stashvr";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "smeagol";
      service = "comfyui";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "durin";
      service = "delugeweb";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "durin";
      service = "flood";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "smeagol";
      service = "invokeai";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "estel";
      service = "kavitan";
      domain = "domain";
    }
    {
      host = "smeagol";
      service = "comfyuimini";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "cirdan";
      service = "mylar";
      domain = "domain";
    }
    {
      host = "durin";
      service = "nzbget";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "durin";
      service = "nzbhydra";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "barliman";
      service = "openwebui";
      domain = "domain";
    }
    {
      host = "durin";
      service = "pinchflat";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "durin";
      service = "radarr";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "durin";
      service = "sickgear";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "durin";
      service = "sonarr";
      domain = "domain";
      proxy = "authentik";
    }
    {
      host = "durin";
      service = "stash";
      domain = "domain";
    }
    {
      host = "cirdan";
      service = "tubearchivist";
      domain = "domain";
    }
  ];

  # Function to generate both regular and punch-through virtual hosts from simple service definitions
  makeServiceHosts =
    serviceList:
    let
      makeHost =
        {
          host,
          service,
          domain,
          proxy ? null,
        }:
        let
          # The actual service host and port
          serviceHostIp = configVars.networking.subnets.${host}.ip;
          servicePortNum = builtins.toString configVars.networking.ports.tcp.${service};

          # Authentik proxy (if enabled)
          useAuthentik = proxy == "authentik";
          authentikIp = configVars.networking.subnets.${authentikHost}.ip;
          authentikPort = builtins.toString configVars.networking.ports.tcp.authentik;

          baseDomain = if domain == "homeDomain" then configVars.homeDomain else configVars.domain;
          subdomain = configVars.networking.subdomains.${service};

          # Regular host configuration
          # If proxy = "authentik", route through Authentik; otherwise go direct to service
          regularHost = {
            "${subdomain}.${baseDomain}" = {
              useACMEHost = "wild-${baseDomain}";
              extraConfig =
                if useAuthentik then
                  ''
                    reverse_proxy ${authentikIp}:${authentikPort}
                  ''
                else
                  ''
                    reverse_proxy ${serviceHostIp}:${servicePortNum}
                  '';
            };
          };

          # Punch-through host configuration
          # Always goes directly to the service (bypassing Authentik) with basic auth
          punchHost = {
            "${subdomain}.${configVars.networking.subdomains.punch}.${baseDomain}" = {
              useACMEHost = "wild-${configVars.networking.subdomains.punch}.${baseDomain}";
              extraConfig = ''
                basic_auth {
                  ${configVars.networking.caddy.basic_auth.punch}
                }
                reverse_proxy ${serviceHostIp}:${servicePortNum}
              '';
            };
          };
        in
        regularHost // punchHost;
    in
    lib.foldl' (acc: service: acc // (makeHost service)) { } serviceList;

  # Generate all simple service hosts (both regular and punch-through)
  generatedHosts = makeServiceHosts simpleServices;
in
{
  services.caddy.enable = true;
  networking.firewall.allowedTCPPorts = [
    80
    443
    2019
  ];

  # Virtual hosts configuration
  # Most services are auto-generated from simpleServices list above
  # Complex configurations (websockets, basic auth, custom certs) are defined manually here
  services.caddy.virtualHosts = generatedHosts // {
    # Special: Bare domain redirect
    "${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        redir https://${configVars.networking.subdomains.authentik}.{host}{uri}
      '';
    };

    # Special: Health check endpoint (not redirected during failover)
    "${configVars.healthDomain}" = {
      useACMEHost = "wild-${configVars.domain}";
      extraConfig = ''
        respond / "Service is UP" 200
      '';
    };

    # Complex: Authentik with websocket support
    "${configVars.networking.subdomains.authentik}.${configVars.homeDomain}" = {
      useACMEHost = "wild-${configVars.homeDomain}";
      extraConfig = ''
        @websockets {
          header Connection *Upgrade*
          header Upgrade websocket
        }
        reverse_proxy @websockets ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik} {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-Proto {scheme}
        }
      '';
    };

    # Punch-through version of authentik (with basic auth for monitoring)
    "${configVars.networking.subdomains.authentik}.${configVars.networking.subdomains.punch}.${configVars.homeDomain}" =
      {
        useACMEHost = "wild-${configVars.networking.subdomains.punch}.${configVars.homeDomain}";
        extraConfig = ''
          basic_auth {
            ${configVars.networking.caddy.basic_auth.punch}
          }
          @websockets {
            header Connection *Upgrade*
            header Upgrade websocket
          }
          reverse_proxy @websockets ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik}
          reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.authentik} {
            header_up Host {host}
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-Proto {scheme}
          }
        '';
      };
  };

  security.acme.acceptTerms = true;
  security.acme.defaults.email = configVars.email.letsencrypt;
  sops.secrets."porkbun/dns-failover/key" = { };
  sops.secrets."porkbun/dns-failover/secret" = { };
  sops.templates."acme-porkbun-secrets.env" = {
    content = ''
      PORKBUN_API_KEY=${config.sops.placeholder."porkbun/dns-failover/key"}
      PORKBUN_SECRET_API_KEY=${config.sops.placeholder."porkbun/dns-failover/secret"}
    '';
    owner = if config.services.caddy.enable then "caddy" else "root";
  };
  security.acme.certs = {
    "${configVars.homeDomain}" = {
      domain = configVars.homeDomain;
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "wild-${configVars.domain}" = {
      domain = "*.${configVars.domain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "wild-${configVars.homeDomain}" = {
      domain = "*.${configVars.homeDomain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "wild-${configVars.networking.subdomains.punch}.${configVars.domain}" = {
      domain = "*.${configVars.networking.subdomains.punch}.${configVars.domain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "wild-${configVars.networking.subdomains.punch}.${configVars.homeDomain}" = {
      domain = "*.${configVars.networking.subdomains.punch}.${configVars.homeDomain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
  };
}
