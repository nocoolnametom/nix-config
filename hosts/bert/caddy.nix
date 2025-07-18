{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
let
  # Helper function to create reverse proxy configuration
  mkReverseProxy = target: extraOpts: ''
    reverse_proxy ${target} {
      header_up Host {host}
      header_up X-Real-IP {remote}
      header_up X-Forwarded-For {remote}
      header_up X-Forwarded-Proto {scheme}
      ${extraOpts}
    }
  '';

  # Helper function to create basic auth configuration
  mkBasicAuth = ''
    basicauth /* {
      file ${config.sops.secrets."bert-caddy-web-authfile".path}
    }
  '';

  # Helper function to create Homer dashboard configuration
  mkHomerDashboard = homerBlocks: ''
    # Serve Homer dashboard
    root * ${pkgs.homer}
    file_server

    # Serve Homer config
    @config /assets/config.yml
    respond @config 200 {
      body ${
        pkgs.writeText "homerConfig.yml" (
          builtins.toJSON {
            title = "Dashboard";
            header = false;
            footer = false;
            connectivityCheck = false;
            columns = "auto";
            services = [
              {
                name = "Services";
                items = homerBlocks;
              }
            ];
          }
        )
      }
      header Content-Type "application/json"
    }
  '';

  # Helper function to create ACME challenge configuration
  mkACMEChallenge = ''
    # ACME challenge
    @acme /.well-known/acme-challenge/*
    file_server @acme {
      root /var/lib/acme/acme-challenge
    }
  '';

  # Import homer blocks
  homerConfig = import ./homer-blocks.nix {
    inherit
      lib
      config
      configVars
      pkgs
      ;
  };
  homerBlocks = homerConfig.homerBlocks;

  # Service configuration function
  mkServiceConfig =
    serviceName: serviceConfig:
    let
      # Default values
      enabled = serviceConfig.enabled or false;
      subdomain = serviceConfig.subdomain or serviceName;
      domains = serviceConfig.domains or [ configVars.domain ];
      actual = serviceConfig.actual or "127.0.0.1";
      port = serviceConfig.port or null;
      forwardHeaders = serviceConfig.forwardHeaders or true;
      basicAuth = serviceConfig.basicAuth or false;
      extraOpts = serviceConfig.extraOpts or "";

      # Build target URL
      targetUrl = if port != null then "http://${actual}:${builtins.toString port}" else null;

      # Build extra config
      extraConfig =
        if targetUrl != null then
          (if basicAuth then mkBasicAuth else "")
          + (if forwardHeaders then mkReverseProxy targetUrl "" else mkReverseProxy targetUrl extraOpts)
        else
          "";

      # Create virtual host entries for each domain
      vhostEntries = lib.mapAttrs' (domain: _: {
        name = "${subdomain}.${domain}";
        value = { inherit extraConfig; };
      }) (lib.genAttrs domains (domain: domain));

    in
    if enabled && targetUrl != null then vhostEntries else { };

  # Service configurations
  services = with configVars.networking; {
    # homeDomain Services
    authentik = {
      enabled = false; # TODO: Enable when authentik service is ready
      subdomain = subdomains.authentik;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.authentik;
      # Authentik requires specific headers for WebSocket support and client IP detection
      extraOpts = ''
        header_up Upgrade {http.request.header.Upgrade}
        header_up Connection {http.request.header.Connection}
      '';
    };

    audiobookshelf = {
      enabled = true;
      subdomain = subdomains.audiobookshelf;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.audiobookshelf;
    };

    calibreweb = {
      enabled = true;
      subdomain = subdomains.calibreweb;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.calibreweb;
    };

    jellyfin = {
      enabled = true;
      subdomain = subdomains.jellyfin;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.jellyfin;
    };

    budget = {
      enabled = true;
      subdomain = subdomains.budget;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.budget;
    };

    budget-me = {
      enabled = true;
      subdomain = subdomains.budget-me;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.budget-me;
    };

    budget-partner = {
      enabled = true;
      subdomain = subdomains.budget-partner;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.budget-partner;
    };

    budget-kid1 = {
      enabled = true;
      subdomain = subdomains.budget-kid1;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.budget-kid1;
    };

    budget-kid2 = {
      enabled = true;
      subdomain = subdomains.budget-kid2;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.budget-kid2;
    };

    podfetch = {
      enabled = true;
      subdomain = subdomains.podfetch;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.podfetch;
    };

    standardnotes-server = {
      enabled = true;
      subdomain = subdomains.standardnotes-server;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.standardnotes-server;
    };

    standardnotes-files = {
      enabled = true;
      subdomain = subdomains.standardnotes-files;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.standardnotes-files;
    };

    standardnotes = {
      enabled = true;
      subdomain = subdomains.standardnotes;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.standardnotes;
    };

    immich = {
      enabled = true;
      subdomain = subdomains.immich;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.immich;
      extraOpts = ''
        request_body {
          max_size 50GB
        }
        timeout 600s
      '';
    };

    immich-share = {
      enabled = true;
      subdomain = subdomains.immich-share;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.immich-share;
    };

    kavita = {
      enabled = true;
      subdomain = subdomains.kavita;
      domains = [ configVars.homeDomain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.kavita;
    };

    navidrome = {
      enabled = config.services.navidrome.enable;
      subdomain = subdomains.navidrome;
      domains = [ configVars.homeDomain ];
      actual = "127.0.0.1";
      port = config.services.navidrome.settings.Port;
    };

    ombi = {
      enabled = config.services.ombi.enable;
      subdomain = subdomains.ombi;
      domains = [ configVars.homeDomain ];
      actual = "127.0.0.1";
      port = config.services.ombi.port;
    };

    radarr = {
      enabled = config.services.radarr.enable;
      subdomain = subdomains.radarr;
      domains = [ configVars.homeDomain ];
      actual = "127.0.0.1";
      port = ports.tcp.radarr;
    };

    sickgear = {
      enabled = config.services.sickbeard.enable;
      subdomain = subdomains.sickgear;
      domains = [ configVars.homeDomain ];
      actual = "127.0.0.1";
      port = config.services.sickbeard.port;
    };

    # domain Services
    comfyui = {
      enabled = true;
      subdomain = subdomains.comfyui;
      domains = [ configVars.domain ];
      actual = subnets.smeagol.ip;
      port = ports.tcp.comfyui;
      basicAuth = true;
    };

    comfyuimini = {
      enabled = true;
      subdomain = subdomains.comfyuimini;
      domains = [ configVars.domain ];
      actual = subnets.smeagol.ip;
      port = ports.tcp.comfyuimini;
      basicAuth = true;
    };

    delugeweb = {
      enabled = config.services.deluge.enable;
      subdomain = subdomains.delugeweb;
      domains = [ configVars.domain ];
      actual = "127.0.0.1";
      port = ports.tcp.delugeweb;
    };

    flood = {
      enabled = config.services.flood.enable;
      subdomain = subdomains.flood;
      domains = [ configVars.domain ];
      actual = "127.0.0.1";
      port = config.services.flood.port;
    };

    kavitan = {
      enabled = true;
      subdomain = subdomains.kavitan;
      domains = [ configVars.domain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.kavitan;
    };

    nzbget = {
      enabled = config.services.nzbget.enable;
      subdomain = subdomains.nzbget;
      domains = [ configVars.domain ];
      actual = "127.0.0.1";
      port = ports.tcp.nzbget;
    };

    phanpy = {
      enabled = true;
      subdomain = subdomains.phanpy;
      domains = [ configVars.domain ];
      forwardHeaders = false; # Static file serving
      extraConfig = ''
        root * ${pkgs.phanpy}
        file_server
      '';
    };

    stash = {
      enabled = config.services.stashapp.enable;
      subdomain = subdomains.stash;
      domains = [ configVars.domain ];
      actual = "127.0.0.1";
      port = config.services.stashapp.port;
    };

    stashvr = {
      enabled = true;
      subdomain = subdomains.stashvr;
      domains = [ configVars.domain ];
      actual = subnets.cirdan.ip;
      port = ports.tcp.stashvr;
    };

    # SSO Services
    kanidm = {
      enabled = config.services.kanidm.enableServer;
      subdomain = "kanidm";
      domains = [ configVars.homeDomain ];
      actual = "127.0.0.1";
      port = 8443; # Default Kanidm port from NixOS service
      # Kanidm requires specific headers for proper operation
      extraOpts = ''
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-For {remote}
        header_up Host {host}
      '';
    };
  };

  # Generate virtual hosts from service configurations
  serviceVirtualHosts = lib.foldl (
    acc: serviceName: acc // (mkServiceConfig serviceName services.${serviceName})
  ) { } (lib.attrNames services);

  # Redirects
  redirects = {
    "www.${configVars.homeDomain}" = {
      extraConfig = "redir https://${configVars.homeDomain}{uri} permanent";
    };
    "house.${configVars.domain}" = {
      extraConfig = "redir https://home.${configVars.domain}{uri} permanent";
    };
    "request.${configVars.homeDomain}" = {
      extraConfig = "redir https://${configVars.networking.subdomains.ombi}.${configVars.homeDomain}{uri} permanent";
    };
    "request.${configVars.domain}" = {
      extraConfig = "redir https://${configVars.networking.subdomains.ombi}.${configVars.domain}{uri} permanent";
    };
    "${configVars.networking.subdomains.stashvr-alias}.${configVars.domain}" = {
      extraConfig = "redir https://${configVars.networking.subdomains.stashvr}.${configVars.domain}{uri} permanent";
    };
  };

in
{
  # Set up sops secret for basic auth file
  sops.secrets."bert-caddy-web-authfile".owner = config.services.caddy.user;

  services.caddy.enable = true;

  # Global Caddy configuration
  services.caddy.globalConfig = ''
    # Default page is a failure - prevent IP-only access unless specified below by IP address
    :80 {
      respond "444" 444
      log {
        output discard
      }
    }
  '';

  # Virtual hosts configuration
  services.caddy.virtualHosts =
    serviceVirtualHosts
    // redirects
    // {
      # Main home domain
      "${configVars.homeDomain}" = {
        extraConfig =
          mkHomerDashboard (
            with homerBlocks false;
            jellyfin
            ++ authentik
            ++ ombi
            ++ navidrome
            ++ calibreweb
            ++ standardnotes
            ++ immich
            ++ kavita
            ++ audiobookshelf
            ++ podfetch
            ++ budget-me
            ++ budget-partner
            ++ budget-kid1
            ++ budget-kid2
            ++ sickgear
            ++ radarr
          )
          + mkACMEChallenge;
      };

      # Private home domain with basic auth
      "home.${configVars.domain}" = {
        extraConfig =
          mkBasicAuth
          + mkHomerDashboard (
            with homerBlocks false;
            vscode
            ++ authentik
            ++ deluge
            ++ flood
            ++ nzbget
            ++ kavitan
            ++ budget-me
            ++ comfyui
            ++ comfyuimini
            ++ stashapp
            ++ stashvr
            ++ phanpy
          )
          + mkACMEChallenge;
      };

      # Local access (localhost, hostname, and IP)
      "localhost" = {
        serverAliases = [
          config.networking.hostName
          configVars.networking.subnets.bert.ip
        ];
        extraConfig = mkHomerDashboard (
          with homerBlocks true;
          vscode
          ++ authentik
          ++ deluge
          ++ flood
          ++ jellyfin
          ++ podfetch
          ++ ombi
          ++ navidrome
          ++ nzbget
          ++ calibreweb
          ++ standardnotes
          ++ immich
          ++ kavita
          ++ kavitan
          ++ audiobookshelf
          ++ comfyui
          ++ comfyuimini
          ++ stashapp
          ++ stashvr
          ++ phanpy
          ++ budget-me
          ++ sickgear
          ++ radarr
        );
      };
    };

  # Caddy automatically handles ACME certificates, so we don't need the manual ACME configuration
  # that was in the nginx config
}
