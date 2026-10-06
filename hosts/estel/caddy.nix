{
  lib,
  config,
  configVars,
  ...
}:
let
  # Authentik proxy host (change here if Authentik moves to a different machine)
  authentikHost = "cirdan";

  # Simple service definitions - just the essentials!
  # Each one becomes a Caddy virtual host
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
  #   healthCheck: (optional) for services behind a login proxy that have no
  #     health URL of their own the proxy can let through. /healthz then
  #     fetches this path straight from the service (skipping the login) and
  #     answers a bare "OK" if it succeeds, so the uptime monitor on bombadil
  #     can see the service without the page's content being exposed.
  #
  # authentik/oauth2 send requests through that proxy for login first; oidc
  # and none go straight to the service, which handles logins itself.
  #
  # Every hostname is a single label under homeDomain or domain, so the two
  # top-level wildcard certs cover all of them. A wildcard matches exactly one
  # label: "*.domain" does not cover "a.b.domain", which would need its own
  # certificate, and every certificate's names are published in the public
  # Certificate Transparency logs. The assertion below keeps it that way.
  simpleServices = [
    # Services on homeDomain
    {
      host = "feanor"; # moved from estel 2026-10-05, next to its libraries
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
      host = "feanor";
      service = "calibreweb";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "hedgedoc";
      domain = "homeDomain";
    }
    {
      host = "feanor";
      service = "immich";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "immich-share";
      domain = "homeDomain";
    }
    {
      host = "feanor";
      service = "jellyfin";
      domain = "homeDomain";
    }
    {
      host = "feanor"; # moved from cirdan's DSM WebDAV 2026-10-05
      service = "webdav";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "karakeep";
      domain = "homeDomain";
    }
    {
      host = "feanor"; # moved from estel 2026-10-05, next to its library
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
      host = "feanor"; # back 2026-10-06, moved from estel next to the music
      service = "navidrome";
      domain = "homeDomain";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel
    }
    {
      host = "estel";
      service = "paperless";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "seerr";
      domain = "homeDomain";
      proxy = "oidc";
    }
    {
      host = "feanor";
      service = "podfetch";
      domain = "homeDomain";
    }
    {
      host = "cirdan";
      service = "portainer";
      domain = "homeDomain";
    }
    {
      host = "estel";
      service = "atuin-sync";
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
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
      healthCheck = "/"; # stash-vr has no health endpoint
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
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
      healthCheck = "/"; # stash-vr has no health endpoint
    }
    {
      host = "smeagol";
      service = "comfyui";
      domain = "domain";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
    }
    {
      host = "durin";
      service = "delugeweb";
      domain = "domain";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
    }
    {
      host = "durin";
      service = "flood";
      domain = "domain";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
    }
    {
      host = "smeagol";
      service = "invokeai";
      domain = "domain";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
    }
    {
      host = "feanor"; # moved from estel 2026-10-05, next to its library
      service = "kavitan";
      domain = "domain";
    }
    {
      host = "smeagol";
      service = "comfyuimini";
      domain = "domain";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
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
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
    }
    {
      host = "durin";
      service = "nzbhydra";
      domain = "domain";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
    }
    {
      host = "barliman";
      service = "openwebui";
      domain = "domain";
    }
    # Hermes Agent API server (Conduit). No SSO proxy: Conduit authenticates with
    # Hermes's own bearer key, which a login redirect would break.
    {
      host = "barliman";
      service = "hermes";
      domain = "domain";
    }
    # Hermes Agent web dashboard; Hermes does the Kanidm OIDC login itself
    {
      host = "barliman";
      service = "hermeswebui";
      domain = "domain";
    }
    # INACTIVE: Pinchflat is not running (disabled on durin); route kept for reference.
    # {
    #   host = "durin";
    #   service = "pinchflat";
    #   domain = "domain";
    #   proxy = "authentik";
    # }
    {
      host = "durin";
      service = "radarr";
      domain = "domain";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
    }
    {
      host = "durin";
      service = "sonarr";
      domain = "domain";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
    }
    {
      host = "feanor";
      service = "tubearchivist";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (forward-auth login)
      domain = "domain";
    }
    {
      host = "durin";
      service = "whisparr";
      domain = "domain";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
    }
    # Runs on durin too, but the published instance is smeagol's
    {
      host = "smeagol";
      service = "whisparr-eros";
      domain = "domain";
      proxy = "oauth2"; # Kanidm via oauth2-proxy on estel (was "authentik")
    }
  ];

  # Function to generate virtual hosts from simple service definitions
  makeServiceHosts =
    serviceList:
    let
      makeHost =
        {
          host,
          service,
          domain,
          proxy ? null,
          healthCheck ? null,
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
          oauth2ProxyIp = "127.0.0.1"; # OAuth2-proxy instances run here on estel
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
              useACMEHost = "wild-${baseDomain}";
              # For oauth2-proxy routes, overwrite X-Forwarded-Uri with the real
              # request URI: oauth2-proxy evaluates skip-auth rules against that
              # header, so a client-supplied value could otherwise bypass login
              # (CVE-2026-40575 / GHSA-7x63-xv5r-3p2x; 7.15.2-7.15.4 still need it).
              extraConfig =
                lib.optionalString (healthCheck != null) ''
                  handle /healthz {
                    rewrite * ${healthCheck}
                    reverse_proxy ${serviceHostIp}:${servicePortNum} {
                      @up status 2xx
                      handle_response @up {
                        respond "OK" 200
                      }
                    }
                  }
                ''
                + (
                  if useOAuth2 then
                    ''
                      handle {
                        reverse_proxy ${proxyTarget} {
                          header_up X-Forwarded-Uri {uri}
                        }
                      }
                    ''
                  else
                    ''
                      handle {
                        reverse_proxy ${proxyTarget}
                      }
                    ''
                );
            };
          };
        in
        regularHost;
    in
    lib.foldl' (acc: service: acc // (makeHost service)) { } serviceList;

  # Generate all simple service hosts
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

  assertions = map (svc: {
    assertion = !lib.hasInfix "." configVars.networking.subdomains.${svc.service};
    message = "caddy: subdomain for ${svc.service} has a dot; the wildcard certs only cover one label (see simpleServices).";
  }) simpleServices;

  services.homelab-status-page.localServices = map (svc: svc.service) (
    lib.filter (svc: svc.host == config.networking.hostName) simpleServices
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
    # Special: Bare domain redirect to Kanidm (its apps page after login)
    "${configVars.homeDomain}" = {
      useACMEHost = configVars.homeDomain;
      extraConfig = ''
        redir https://${configVars.networking.subdomains.kanidm}.{host}{uri}
      '';
    };

    # Special: Komodo (container manager on feanor) for LAN clients only. It
    # needs HTTPS for its Kanidm login, but is root-equivalent on feanor, so
    # anything not from the LAN gets 403. LAN clients reach this name through
    # the router's NAT loopback (seen here as 192.168.0.1); outside visitors
    # keep their own addresses, and bombadil's tunnel uses 10.100.0.0/24.
    # Caddy listens on IPv6 sockets, so LAN peers can also appear as
    # IPv4-mapped addresses (::ffff:192.168.0.1); both forms are allowed.
    "${configVars.networking.subdomains.komodo}.${configVars.homeDomain}" = {
      useACMEHost = "wild-${configVars.homeDomain}";
      extraConfig = ''
        @outside not remote_ip 192.168.0.0/16 ::ffff:192.168.0.0/112
        respond @outside "LAN only" 403
        reverse_proxy ${configVars.networking.subnets.feanor.ip}:${toString configVars.networking.ports.tcp.komodo}
      '';
    };

    # Special: Health check endpoint (not redirected during failover)
    "${configVars.healthDomain}" = {
      useACMEHost = "wild-${configVars.domain}";
      extraConfig = ''
        respond / "Service is UP" 200
      '';
    };

    # Special: Legacy requests URL (was Ombi) now redirects to Seerr
    "requests.${configVars.homeDomain}" = {
      useACMEHost = "wild-${configVars.homeDomain}";
      extraConfig = ''
        redir https://${configVars.networking.subdomains.seerr}.${configVars.homeDomain}{uri}
      '';
    };
    # Legacy: Immich share links sent before 2026-10-06 used
    # share.<immich>.<homeDomain>. Kept so those links keep working; the
    # "wild-immich" cert below exists only for this. Drop both once old
    # links no longer matter.
    "share.${configVars.networking.subdomains.immich}.${configVars.homeDomain}" = {
      useACMEHost = "wild-immich";
      extraConfig = ''
        redir https://${configVars.networking.subdomains.immich-share}.${configVars.homeDomain}{uri} permanent
      '';
    };

    # Special: Additional domain for autocaliweb
    "${configVars.networking.subdomains.calibreweb2}.${configVars.homeDomain}" = {
      useACMEHost = "wild-${configVars.homeDomain}";
      extraConfig = ''
        redir https://${configVars.networking.subdomains.calibreweb}.${configVars.homeDomain}{uri}
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

    # Kanidm SSO server - hosted on feanor, proxied from estel over the LAN.
    # Uses wildcard cert so sso.<homeDomain> never appears in CT logs.
    # Same pattern as every other homelab service: estel terminates TLS, then
    # forwards to the service host's LAN IP.
    "${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}" = {
      useACMEHost = "wild-${configVars.homeDomain}";
      # PodFetch derives its token URL as "<authorise URL>/../token"; with
      # Kanidm's /ui/oauth2 that lands on /ui/token (see hosts/feanor/podfetch.nix).
      extraConfig = ''
        rewrite /ui/token /oauth2/token
        reverse_proxy https://${configVars.networking.subnets.feanor.ip}:${builtins.toString configVars.networking.ports.tcp.kanidm} {
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
    # Only for the legacy share-link redirect above.
    "wild-immich" = {
      domain = "*.${configVars.networking.subdomains.immich}.${configVars.homeDomain}";
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
    # Standalone kanidm cert removed: Kanidm runs on feanor and uses feanor's
    # wildcard cert. The per-subdomain cert here leaked sso.<homeDomain> to CT
    # logs and is no longer needed; Caddy's kanidm vhost above uses wild-${configVars.homeDomain}.
  };
}
