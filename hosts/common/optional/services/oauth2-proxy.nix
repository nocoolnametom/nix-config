{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
{
  # Enable OAuth2-proxy service
  services.oauth2-proxy-multi.enable = lib.mkDefault configVars.enableKanidmSSO;

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

  # Configure OAuth2-proxy instances
  services.oauth2-proxy-multi.instances = {
    # estel services (2)
    navidrome = {
      port = configVars.networking.ports.tcp.oauth2-navidrome;
      upstreamUrl = "http://${configVars.networking.subnets.estel.ip}:${toString configVars.networking.ports.tcp.navidrome}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "navidrome";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/navidrome/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/navidrome/cookie-secret".path;
      # Navidrome-specific: use X-Forwarded-User header
      passUserHeaders = true;
      setXAuthRequest = true;
    };

    ombi = {
      port = configVars.networking.ports.tcp.oauth2-ombi;
      upstreamUrl = "http://${configVars.networking.subnets.estel.ip}:${toString configVars.networking.ports.tcp.ombi}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "ombi";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/ombi/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/ombi/cookie-secret".path;
    };

    # smeagol services (4)
    comfyui = {
      port = configVars.networking.ports.tcp.oauth2-comfyui;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.comfyui}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "comfyui";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/comfyui/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/comfyui/cookie-secret".path;
    };

    comfyuimini = {
      port = configVars.networking.ports.tcp.oauth2-comfyuimini;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.comfyuimini}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "comfyuimini";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/comfyuimini/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/comfyuimini/cookie-secret".path;
    };

    invokeai = {
      port = configVars.networking.ports.tcp.oauth2-invokeai;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.invokeai}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "invokeai";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/invokeai/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/invokeai/cookie-secret".path;
    };

    archerstashvr = {
      port = configVars.networking.ports.tcp.oauth2-archerstashvr;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.archerstashvr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "archerstashvr";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/archerstashvr/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/archerstashvr/cookie-secret".path;
    };

    # durin services (9)
    delugeweb = {
      port = configVars.networking.ports.tcp.oauth2-delugeweb;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.delugeweb}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "delugeweb";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/delugeweb/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/delugeweb/cookie-secret".path;
    };

    flood = {
      port = configVars.networking.ports.tcp.oauth2-flood;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.flood}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "flood";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/flood/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/flood/cookie-secret".path;
    };

    nzbget = {
      port = configVars.networking.ports.tcp.oauth2-nzbget;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.nzbget}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "nzbget";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/nzbget/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/nzbget/cookie-secret".path;
    };

    nzbhydra = {
      port = configVars.networking.ports.tcp.oauth2-nzbhydra;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.nzbhydra}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "nzbhydra";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/nzbhydra/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/nzbhydra/cookie-secret".path;
    };

    pinchflat = {
      port = configVars.networking.ports.tcp.oauth2-pinchflat;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.pinchflat}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "pinchflat";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/pinchflat/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/pinchflat/cookie-secret".path;
    };

    radarr = {
      port = configVars.networking.ports.tcp.oauth2-radarr;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.radarr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "radarr";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/radarr/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/radarr/cookie-secret".path;
    };

    sickgear = {
      port = configVars.networking.ports.tcp.oauth2-sickgear;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.sickgear}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "sickgear";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/sickgear/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/sickgear/cookie-secret".path;
    };

    sonarr = {
      port = configVars.networking.ports.tcp.oauth2-sonarr;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.sonarr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "sonarr";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/sonarr/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/sonarr/cookie-secret".path;
    };

    stashvr = {
      port = configVars.networking.ports.tcp.oauth2-stashvr;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.stashvr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
      clientId = "stashvr";
      clientSecretFile = config.sops.secrets."homelab/kanidm/oauth2/stashvr/client-secret".path;
      cookieSecretFile = config.sops.secrets."homelab/oauth2/stashvr/cookie-secret".path;
    };
  };
}
