{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
lib.mkIf configVars.enableKanidmSSO {
  # OAuth2-proxy: Generic OIDC reverse proxy
  # Currently configured to use Kanidm as the OIDC provider, but can work with any
  # OIDC-compliant provider (Keycloak, Auth0, Okta, etc.) by changing oidcIssuerUrl
  services.oauth2-proxy-multi.enable = true;

  # Define SOPS secrets for cookie encryption (all 15 services)
  # Must be readable by oauth2-proxy user
  sops.secrets."homelab/oauth2/navidrome/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/ombi/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/comfyui/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/comfyuimini/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/invokeai/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/archerstashvr/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/delugeweb/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/flood/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/nzbget/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/nzbhydra/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/pinchflat/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/radarr/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/sickgear/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/sonarr/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/oauth2/stashvr/cookie-secret" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };

  # HTTP Basic Auth credentials (for services that require them)
  # Must be readable by oauth2-proxy user
  sops.secrets."homelab/nzbget-durin/username" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/nzbget-durin/password" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/radarr/username" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/radarr/password" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/sonarr/username" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."homelab/sonarr/password" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."pinchflat/username" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."pinchflat/password" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."deluge-password" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."flood-user" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };
  sops.secrets."flood-pass" = {
    owner = config.services.oauth2-proxy-multi.user;
    group = config.services.oauth2-proxy-multi.group;
  };

  # Configure OAuth2-proxy instances
  services.oauth2-proxy-multi.instances = {
    # estel services (2)
    navidrome = {
      port = configVars.networking.ports.tcp.oauth2-navidrome;
      upstreamUrl = "http://${configVars.networking.subnets.estel.ip}:${toString configVars.networking.ports.tcp.navidrome}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/navidrome";
      clientId = "navidrome";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/navidrome/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/navidrome/cookie-secret".path;
      # Navidrome-specific: use X-Forwarded-User header
      passUserHeaders = true;
      setXAuthRequest = true;
      # Allow unauthenticated access to health checks and shared links
      skipAuthRegex = [
        "^/ping$"
        "^/share/"
      ];
    };

    ombi = {
      port = configVars.networking.ports.tcp.oauth2-ombi;
      upstreamUrl = "http://${configVars.networking.subnets.estel.ip}:${toString configVars.networking.ports.tcp.ombi}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/ombi";
      clientId = "ombi";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/ombi/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/ombi/cookie-secret".path;
      # Allow API access for Plex/Jellyfin integration and mobile apps
      skipAuthRegex = [ "^/api/.*" ];
    };

    # smeagol services (4)
    comfyui = {
      port = configVars.networking.ports.tcp.oauth2-comfyui;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.comfyui}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/comfyui";
      clientId = "comfyui";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/comfyui/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/comfyui/cookie-secret".path;
    };

    comfyuimini = {
      port = configVars.networking.ports.tcp.oauth2-comfyuimini;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.comfyuimini}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/comfyuimini";
      clientId = "comfyuimini";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/comfyuimini/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/comfyuimini/cookie-secret".path;
    };

    invokeai = {
      port = configVars.networking.ports.tcp.oauth2-invokeai;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.invokeai}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/invokeai";
      clientId = "invokeai";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/invokeai/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/invokeai/cookie-secret".path;
    };

    archerstashvr = {
      port = configVars.networking.ports.tcp.oauth2-archerstashvr;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.archerstashvr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/archerstashvr";
      clientId = "archerstashvr";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/archerstashvr/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/archerstashvr/cookie-secret".path;
      # Allow VR player access (paths from nix-secrets to avoid exposing API key structure)
      skipAuthRegex = configVars.networking.stash.vrProxyPaths;
    };

    # durin services (9)
    delugeweb = {
      port = configVars.networking.ports.tcp.oauth2-delugeweb;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.delugeweb}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/delugeweb";
      clientId = "delugeweb";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/delugeweb/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/delugeweb/cookie-secret".path;
      # Pass HTTP Basic Auth to upstream (Deluge requires it)
      # Note: Deluge username is typically in the config, only password from secrets
      basicAuthPasswordFile = config.sops.secrets."deluge-password".path;
    };

    flood = {
      port = configVars.networking.ports.tcp.oauth2-flood;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.flood}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/flood";
      clientId = "flood";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/flood/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/flood/cookie-secret".path;
      # Pass HTTP Basic Auth to upstream
      basicAuthUsernameFile = config.sops.secrets."flood-user".path;
      basicAuthPasswordFile = config.sops.secrets."flood-pass".path;
    };

    nzbget = {
      port = configVars.networking.ports.tcp.oauth2-nzbget;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.nzbget}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/nzbget";
      clientId = "nzbget";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/nzbget/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/nzbget/cookie-secret".path;
      # Pass HTTP Basic Auth to upstream (NZBGet requires it)
      basicAuthUsernameFile = config.sops.secrets."homelab/nzbget-durin/username".path;
      basicAuthPasswordFile = config.sops.secrets."homelab/nzbget-durin/password".path;
    };

    nzbhydra = {
      port = configVars.networking.ports.tcp.oauth2-nzbhydra;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.nzbhydra}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/nzbhydra";
      clientId = "nzbhydra";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/nzbhydra/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/nzbhydra/cookie-secret".path;
      # Allow health check endpoint
      skipAuthRegex = [ "^/actuator/health/ping$" ];
    };

    pinchflat = {
      port = configVars.networking.ports.tcp.oauth2-pinchflat;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.pinchflat}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/pinchflat";
      clientId = "pinchflat";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/pinchflat/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/pinchflat/cookie-secret".path;
      # Pass HTTP Basic Auth to upstream
      basicAuthUsernameFile = config.sops.secrets."pinchflat/username".path;
      basicAuthPasswordFile = config.sops.secrets."pinchflat/password".path;
    };

    radarr = {
      port = configVars.networking.ports.tcp.oauth2-radarr;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.radarr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/radarr";
      clientId = "radarr";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/radarr/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/radarr/cookie-secret".path;
      # Allow health check endpoint
      skipAuthRegex = [ "^/ping$" ];
      # Pass HTTP Basic Auth to upstream (for API clients)
      basicAuthUsernameFile = config.sops.secrets."homelab/radarr/username".path;
      basicAuthPasswordFile = config.sops.secrets."homelab/radarr/password".path;
    };

    sickgear = {
      port = configVars.networking.ports.tcp.oauth2-sickgear;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.sickgear}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/sickgear";
      clientId = "sickgear";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/sickgear/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/sickgear/cookie-secret".path;
    };

    sonarr = {
      port = configVars.networking.ports.tcp.oauth2-sonarr;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.sonarr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/sonarr";
      clientId = "sonarr";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/sonarr/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/sonarr/cookie-secret".path;
      # Allow health check endpoint
      skipAuthRegex = [ "^/ping$" ];
      # Pass HTTP Basic Auth to upstream (for API clients)
      basicAuthUsernameFile = config.sops.secrets."homelab/sonarr/username".path;
      basicAuthPasswordFile = config.sops.secrets."homelab/sonarr/password".path;
    };

    stashvr = {
      port = configVars.networking.ports.tcp.oauth2-stashvr;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.stashvr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/stashvr";
      clientId = "stashvr";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/stashvr/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/stashvr/cookie-secret".path;
      # Allow VR player access (paths from nix-secrets to avoid exposing API key structure)
      skipAuthRegex = configVars.networking.stash.vrProxyPaths;
    };
  };
}
