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
  #   proxy: (optional) SSO provider type - use configVars.proxyTypes constants
  #     - configVars.proxyTypes.authentik: Route through Authentik's built-in proxy
  #     - configVars.proxyTypes.oauth2: Route through OAuth2-proxy (works with any OIDC provider)
  #     - configVars.proxyTypes.oidc: Direct to service (service has native OIDC integration)
  #     - configVars.proxyTypes.none or null/unset: No SSO, direct to service
  #
  # When proxy = configVars.proxyTypes.authentik:
  #   - Regular domain: service.domain → caddy → authentik → host:service (SSO authentication)
  #   - Punch domain: service.punch.domain → caddy → host:service (basic auth, bypasses Authentik for monitoring)
  #
  # When proxy = configVars.proxyTypes.oauth2:
  #   - Regular domain: service.domain → caddy → oauth2-proxy → host:service (SSO via OAuth2-proxy)
  #   - Punch domain: service.punch.domain → caddy → host:service (basic auth, bypasses OAuth2-proxy)
  #
  # When proxy = configVars.proxyTypes.oidc or proxy is not set:
  #   - Both regular and punch domains go directly to service
  #   - Punch domain adds basic auth for monitoring
  #   - (OIDC services handle authentication internally)
  simpleServices = [
    # Services on homeDomain
    {
      host = "estel";
      service = "audiobookshelf";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "beszel";
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
      certName = "wild-immich";
      punchCertName = "wild-immich-punch";
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
    # Disabled 2026-03-04: Navidrome build failure
    # {
    #   host = "estel";
    #   service = "navidrome";
    #   domain = "homeDomain";
    #   proxy = "authentik";
    # }
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
      certName = "wild-stash";
      punchCertName = "wild-stash-punch";
    }
    {
      host = "smeagol";
      service = "archerstashvr";
      domain = "domain";
      proxy = "authentik";
      certName = "wild-stash-vr";
      punchCertName = "wild-stash-vr-punch";
    }
    {
      host = "durin";
      service = "stash";
      domain = "domain";
    }
    {
      host = "durin";
      service = "stashvr";
      domain = "domain";
      proxy = "authentik";
      certName = "wild-${configVars.domain}";
      punchCertName = "wild-${configVars.networking.subdomains.punch}.${configVars.domain}";
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
      service = "miniflux";
      domain = "homeDomain";
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
      host = "cirdan";
      service = "tubearchivist";
      domain = "domain";
    }
  ];

  serviceBlacklist = configVars.homepage.serviceBlacklist or [ ];

  resolveServicePort =
    serviceName:
    let
      portFromNetworking = lib.attrByPath [ serviceName ] null configVars.networking.ports.tcp;
      portFromServiceConfig = lib.findFirst (port: port != null) null [
        (lib.attrByPath [ "services" serviceName "port" ] null config)
        (lib.attrByPath [ "services" serviceName "listenPort" ] null config)
        (lib.attrByPath [ "services" serviceName "settings" "Port" ] null config)
        (lib.attrByPath [ "services" serviceName "settings" "port" ] null config)
      ];
      resolvedPort = if portFromNetworking != null then portFromNetworking else portFromServiceConfig;
    in
    if resolvedPort == null then null else builtins.toString resolvedPort;

  localHomepageServices =
    let
      serviceEntries = lib.filter (svc: svc.host == config.networking.hostName) simpleServices;
      visibleServices = lib.filter (svc: !(lib.elem svc.service serviceBlacklist)) serviceEntries;
      withPorts = lib.filter (svc: svc.port != null) (
        map (svc: svc // { port = resolveServicePort svc.service; }) visibleServices
      );
    in
    lib.sort (a: b: a.service < b.service) withPorts;

  localServiceLinksHtml =
    if localHomepageServices == [ ] then
      "<p>No local services found.</p>"
    else
      ''
        <ul class="services">
          ${lib.concatMapStringsSep "\n" (svc: ''
            <li><a href="http://${config.networking.hostName}.${configVars.homeLanDomain}:${svc.port}">${svc.service}</a></li>
          '') localHomepageServices}
        </ul>
      '';

  statusPageContent = pkgs.writeTextDir "index.html" ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${config.networking.hostName} Status</title>
      <style>
        body {
          font-family: system-ui, -apple-system, sans-serif;
          margin: 2rem auto;
          max-width: 52rem;
          line-height: 1.5;
          padding: 0 1rem;
          color: #111827;
          background: #f9fafb;
        }
        .card {
          background: white;
          border-radius: 12px;
          padding: 1.25rem;
          box-shadow: 0 1px 4px rgba(0, 0, 0, 0.08);
        }
        h1, h2 {
          margin-top: 0;
        }
        .meta {
          margin-bottom: 1rem;
        }
        .meta div {
          margin: 0.25rem 0;
        }
        ul.services {
          margin: 0.5rem 0 0;
          padding-left: 1.2rem;
        }
        ul.services li {
          margin: 0.2rem 0;
        }
        a {
          color: #2563eb;
          text-decoration: none;
        }
        a:hover {
          text-decoration: underline;
        }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>${config.networking.hostName}</h1>
        <div class="meta">
          <div><strong>Status:</strong> System Running</div>
          <div><strong>NixOS Version:</strong> ${config.system.nixos.version or "N/A"}</div>
          <div><strong>Hostname:</strong> ${config.networking.hostName}.${configVars.homeLanDomain}</div>
        </div>
        <h2>Local Services</h2>
        ${localServiceLinksHtml}
      </div>
    </body>
    </html>
  '';

  # Function to generate both regular and punch-through virtual hosts from simple service definitions
  makeServiceHosts =
    serviceList:
    let
      makeHost =
        {
          host,
          service,
          domain,
          certName ? null,
          punchCertName ? null,
          proxy ? null,
        }:
        let
          # The actual service host and port
          serviceHostIp = configVars.networking.subnets.${host}.ip;
          servicePortNum = builtins.toString configVars.networking.ports.tcp.${service};

          # Authentik proxy (if enabled)
          useAuthentik = proxy == configVars.proxyTypes.authentik;
          authentikIp = configVars.networking.subnets.${authentikHost}.ip;
          authentikPort = builtins.toString configVars.networking.ports.tcp.authentik;

          # OAuth2-proxy (if enabled) - generic reverse proxy for OIDC providers
          useOAuth2 = proxy == configVars.proxyTypes.oauth2;
          oauth2ProxyIp = serviceHostIp; # OAuth2-proxy runs on same host as service
          oauth2ProxyPort = builtins.toString configVars.networking.ports.tcp."oauth2-${service}";

          # Native OIDC (if enabled) - service handles OIDC internally
          useOidc = proxy == configVars.proxyTypes.oidc;

          baseDomain = if domain == "homeDomain" then configVars.homeDomain else configVars.domain;
          subdomain = configVars.networking.subdomains.${service};

          # Determine proxy target based on proxy type
          proxyTarget =
            if useAuthentik then
              "${authentikIp}:${authentikPort}"
            else if useOAuth2 then
              "${oauth2ProxyIp}:${oauth2ProxyPort}"
            # useOidc or null - both go directly to service
            else
              "${serviceHostIp}:${servicePortNum}";

          # Regular host configuration
          # Routes through Authentik, OAuth2-proxy, or direct to service based on proxy setting
          regularHost = {
            "${subdomain}.${baseDomain}" = {
              useACMEHost = if certName == null then "wild-${baseDomain}" else certName;
              extraConfig = ''
                reverse_proxy ${proxyTarget}
              '';
            };
          };

          # Punch-through host configuration
          # Always goes directly to the service (bypassing SSO proxies) with basic auth
          punchHost = {
            "${subdomain}.${configVars.networking.subdomains.punch}.${baseDomain}" = {
              useACMEHost =
                if punchCertName == null then
                  "wild-${configVars.networking.subdomains.punch}.${baseDomain}"
                else
                  punchCertName;
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
  # Export SSO provider configuration from simpleServices
  services.ssoProvider = lib.listToAttrs (
    lib.filter (x: x != null) (
      map (
        svc:
        if svc.proxy or null != null then
          {
            name = svc.service;
            value = svc.proxy;
          }
        else
          null
      ) simpleServices
    )
  );

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
    # Host LAN status page and local service links
    "http://${config.networking.hostName}.${configVars.homeLanDomain}" = {
      extraConfig = ''
        root * ${statusPageContent}
        file_server
      '';
    };

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

    # Kanidm SSO server
    "${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}" = {
      useACMEHost = "${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      extraConfig = ''
        reverse_proxy https://${configVars.networking.subnets.estel.ip}:${builtins.toString configVars.networking.ports.tcp.kanidm} {
          transport http {
            tls_insecure_skip_verify
          }
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
      extraDomainNames = [ configVars.domain ];
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "wild-immich" = {
      domain = "*.${configVars.networking.subdomains.immich}.${configVars.homeDomain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "wild-immich-punch" = {
      domain = "*.${configVars.networking.subdomains.immich}.${configVars.networking.subdomains.punch}.${configVars.homeDomain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "wild-stash" = {
      domain = "*.${configVars.networking.subdomains.stash}.${configVars.domain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "wild-stash-punch" = {
      domain = "*.${configVars.networking.subdomains.stash}.${configVars.networking.subdomains.punch}.${configVars.domain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "wild-stash-vr" = {
      domain = "*.${configVars.networking.subdomains.stashvr}.${configVars.domain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "wild-stash-vr-punch" = {
      domain = "*.${configVars.networking.subdomains.stashvr}.${configVars.networking.subdomains.punch}.${configVars.domain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "wild-${configVars.homeDomain}" = {
      domain = "*.${configVars.homeDomain}";
      extraDomainNames = [ configVars.homeDomain ];
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
    "${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}" = {
      domain = "${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
  };
}
