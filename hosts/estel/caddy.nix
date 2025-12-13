{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
let
  # Simple service definitions - just the essentials!
  # These will be automatically converted to both regular and punch-through hosts
  simpleServices = [
    # Services on homeDomain (doggett.family)
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
      host = "estel";
      service = "hedgedoc";
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
      host = "cirdan";
      service = "navidrome";
      domain = "homeDomain";
      port = "authentik";
    }
    {
      host = "cirdan";
      service = "ombi";
      domain = "homeDomain";
      port = "authentik";
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

    # Services on domain (nocoolnametom.com)
    {
      host = "cirdan";
      service = "comfyui";
      domain = "domain";
      port = "authentik";
    }
    {
      host = "cirdan";
      service = "comfyuimini";
      domain = "domain";
      port = "authentik";
    }
    {
      host = "cirdan";
      service = "delugeweb";
      domain = "domain";
      port = "authentik";
    }
    {
      host = "cirdan";
      service = "flood";
      domain = "domain";
      port = "authentik";
    }
    {
      host = "cirdan";
      service = "nzbhydra";
      domain = "domain";
      port = "authentik";
    }
    {
      host = "estel";
      service = "kavitan";
      domain = "domain";
    }
    {
      host = "cirdan";
      service = "mylar";
      domain = "domain";
    }
    {
      host = "cirdan";
      service = "nzbget";
      domain = "domain";
      port = "authentik";
    }
    {
      host = "smeagol";
      service = "openwebui";
      domain = "domain";
    }
    {
      host = "bert";
      service = "pinchflat";
      domain = "domain";
    }
    {
      host = "cirdan";
      service = "radarr";
      domain = "domain";
      port = "authentik";
    }
    {
      host = "cirdan";
      service = "sickgear";
      domain = "domain";
      port = "authentik";
    }
    {
      host = "cirdan";
      service = "sonarr";
      domain = "domain";
      port = "authentik";
    }
    {
      host = "bert";
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
          port ? null,
        }:
        let
          hostIp = configVars.networking.subnets.${host}.ip;
          # If port is not specified, use the service name as the port key
          portKey = if port != null then port else service;
          portNum = builtins.toString configVars.networking.ports.tcp.${portKey};
          baseDomain = if domain == "homeDomain" then configVars.homeDomain else configVars.domain;
          subdomain = configVars.networking.subdomains.${service};

          # Regular host configuration
          regularHost = {
            "${subdomain}.${baseDomain}" = {
              useACMEHost = "wild-${baseDomain}";
              extraConfig = ''
                reverse_proxy ${hostIp}:${portNum}
              '';
            };
          };

          # Punch-through host configuration
          punchHost = {
            "${subdomain}.${configVars.networking.subdomains.punch}.${baseDomain}" = {
              useACMEHost = "wild-${configVars.networking.subdomains.punch}.${baseDomain}";
              extraConfig = ''
                reverse_proxy ${hostIp}:${portNum}
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

    # Punch-through version of authentik
    "${configVars.networking.subdomains.authentik}.${configVars.networking.subdomains.punch}.${configVars.homeDomain}" =
      {
        useACMEHost = "wild-${configVars.networking.subdomains.punch}.${configVars.homeDomain}";
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

    # Complex: Custom SSL certs (not wildcard)
    "${configVars.networking.subdomains.archerstash}.${configVars.domain}" = {
      useACMEHost = "${configVars.networking.subdomains.archerstash}.${configVars.domain}";
      extraConfig = ''
        reverse_proxy ${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.archerstash}
      '';
    };
    "${configVars.networking.subdomains.archerstash}.${configVars.networking.subdomains.punch}.${configVars.domain}" =
      {
        useACMEHost = "${configVars.networking.subdomains.archerstash}.${configVars.networking.subdomains.punch}.${configVars.domain}";
        extraConfig = ''
          reverse_proxy ${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.archerstash}
        '';
      };

    "${configVars.networking.subdomains.archerstashvr}.${configVars.domain}" = {
      useACMEHost = "${configVars.networking.subdomains.archerstashvr}.${configVars.domain}";
      extraConfig = ''
        basic_auth {
          ${configVars.networking.caddy.basic_auth.archer-stashvr}
        }
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.archerstashvr}
      '';
    };
    "${configVars.networking.subdomains.archerstashvr}.${configVars.networking.subdomains.punch}.${configVars.domain}" =
      {
        useACMEHost = "${configVars.networking.subdomains.archerstashvr}.${configVars.networking.subdomains.punch}.${configVars.domain}";
        extraConfig = ''
          basic_auth {
            ${configVars.networking.caddy.basic_auth.archer-stashvr}
          }
          reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.archerstashvr}
        '';
      };

    # Complex: Basic auth required
    "${configVars.networking.subdomains.stashvr}.${configVars.domain}" = {
      useACMEHost = "wild-${configVars.domain}";
      extraConfig = ''
        basic_auth {
          ${configVars.networking.caddy.basic_auth.stashvr}
        }
        reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.stashvr}
      '';
    };

    # Punch-through version of stashvr
    "${configVars.networking.subdomains.stashvr}.${configVars.networking.subdomains.punch}.${configVars.domain}" =
      {
        useACMEHost = "wild-${configVars.networking.subdomains.punch}.${configVars.domain}";
        extraConfig = ''
          basic_auth {
            ${configVars.networking.caddy.basic_auth.stashvr}
          }
          reverse_proxy ${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.stashvr}
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
    "${configVars.networking.subdomains.archerstash}.${configVars.domain}" = {
      domain = "${configVars.networking.subdomains.archerstash}.${configVars.domain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
    "${configVars.networking.subdomains.archerstashvr}.${configVars.domain}" = {
      domain = "${configVars.networking.subdomains.archerstashvr}.${configVars.domain}";
      group = "caddy";
      dnsProvider = "porkbun";
      environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
    };
  };
}
