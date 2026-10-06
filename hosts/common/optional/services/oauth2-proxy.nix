###############################################################################
#
#  OAuth2-proxy instances in front of apps without their own OIDC support,
#  authenticating against Kanidm. They run on estel, the reverse-proxy host:
#  Caddy routes a service through 127.0.0.1:<oauth2 port> when its
#  simpleServices entry has proxy = "oauth2", and each instance forwards to
#  the service's own host over the LAN.
#
#  Hosts opt in per instance:
#    services.homelab-oauth2-proxy.instances = [ "archerstashvr" ];
#  Only listed instances run, and only their secrets are declared.
#
#  Moving an instance to an exact-redirect provider like Kanidm also needs
#  `externalUrl` here and a matching .../oauth2/callback originUrl on the
#  Kanidm client in kanidm.nix.
#
###############################################################################

{
  lib,
  config,
  configVars,
  ...
}:
let
  enabled = config.services.homelab-oauth2-proxy.instances;
  # Instances whose service is published on homeDomain (the rest use domain).
  homeDomainInstances = [
    "navidrome"
    "seerr"
  ];
  secret = name: config.sops.secrets.${name}.path;

  # Secrets each instance reads (Kanidm client secret, cookie secret, and any
  # upstream basic-auth credentials).
  instanceSecrets =
    lib.genAttrs
      [
        "navidrome"
        "seerr"
        "comfyui"
        "comfyuimini"
        "invokeai"
        "archerstashvr"
        "delugeweb"
        "flood"
        "nzbget"
        "nzbhydra"
        "pinchflat"
        "radarr"
        "sonarr"
        "stashvr"
        "whisparr"
        "whisparr-eros"
        "tubearchivist"
      ]
      (n: [
        "homelab/kanidm/oauth2/${n}/client-secret"
        "homelab/oauth2/${n}/cookie-secret"
      ])
    // {
      delugeweb = [
        "homelab/kanidm/oauth2/delugeweb/client-secret"
        "homelab/oauth2/delugeweb/cookie-secret"
        "deluge-password"
      ];
      flood = [
        "homelab/kanidm/oauth2/flood/client-secret"
        "homelab/oauth2/flood/cookie-secret"
        "flood-user"
        "flood-pass"
      ];
      nzbget = [
        "homelab/kanidm/oauth2/nzbget/client-secret"
        "homelab/oauth2/nzbget/cookie-secret"
        "homelab/nzbget-durin/username"
        "homelab/nzbget-durin/password"
      ];
      pinchflat = [
        "homelab/kanidm/oauth2/pinchflat/client-secret"
        "homelab/oauth2/pinchflat/cookie-secret"
        "pinchflat/username"
        "pinchflat/password"
      ];
      radarr = [
        "homelab/kanidm/oauth2/radarr/client-secret"
        "homelab/oauth2/radarr/cookie-secret"
        "homelab/radarr/username"
        "homelab/radarr/password"
      ];
      sonarr = [
        "homelab/kanidm/oauth2/sonarr/client-secret"
        "homelab/oauth2/sonarr/cookie-secret"
        "homelab/sonarr/username"
        "homelab/sonarr/password"
      ];
      whisparr = [
        "homelab/kanidm/oauth2/whisparr/client-secret"
        "homelab/oauth2/whisparr/cookie-secret"
        "homelab/whisparr/username"
        "homelab/whisparr/password"
      ];
      whisparr-eros = [
        "homelab/kanidm/oauth2/whisparr-eros/client-secret"
        "homelab/oauth2/whisparr-eros/cookie-secret"
        "homelab/whisparr-eros/username"
        "homelab/whisparr-eros/password"
      ];
    };

  allInstances = {
    # estel services (2)
    navidrome = {
      port = configVars.networking.ports.tcp.oauth2-navidrome;
      # Navidrome runs on feanor (navidrome.nix) and trusts the username
      # header only from estel, where this instance runs.
      upstreamUrl = "http://${configVars.networking.subnets.feanor.ip}:${toString configVars.networking.ports.tcp.navidrome}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/navidrome";
      clientId = "navidrome";
      clientSecretFile = secret "homelab/kanidm/oauth2/navidrome/client-secret";
      cookieSecretFile = secret "homelab/oauth2/navidrome/cookie-secret";
      # Navidrome reads X-Forwarded-Preferred-Username (short name, see the
      # Kanidm client).
      passUserHeaders = true;
      setXAuthRequest = true;
      # Health checks and public share links skip the login; so does the
      # Subsonic API, whose clients (phone apps) authenticate against
      # Navidrome's own user passwords.
      skipAuthRegex = [
        "^/ping$"
        "^/share/"
        "^/rest/"
      ];
    };

    seerr = {
      port = configVars.networking.ports.tcp.oauth2-seerr;
      upstreamUrl = "http://${configVars.networking.subnets.estel.ip}:${toString configVars.networking.ports.tcp.seerr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/seerr";
      clientId = "seerr";
      clientSecretFile = secret "homelab/kanidm/oauth2/seerr/client-secret";
      cookieSecretFile = secret "homelab/oauth2/seerr/cookie-secret";
      # Allow API access for Plex/Jellyfin integration and mobile apps
      skipAuthRegex = [ "^/api/.*" ];
    };

    # smeagol services (4)
    comfyui = {
      port = configVars.networking.ports.tcp.oauth2-comfyui;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.comfyui}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/comfyui";
      clientId = "comfyui";
      clientSecretFile = secret "homelab/kanidm/oauth2/comfyui/client-secret";
      cookieSecretFile = secret "homelab/oauth2/comfyui/cookie-secret";
    };

    comfyuimini = {
      port = configVars.networking.ports.tcp.oauth2-comfyuimini;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.comfyuimini}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/comfyuimini";
      clientId = "comfyuimini";
      clientSecretFile = secret "homelab/kanidm/oauth2/comfyuimini/client-secret";
      cookieSecretFile = secret "homelab/oauth2/comfyuimini/cookie-secret";
    };

    invokeai = {
      port = configVars.networking.ports.tcp.oauth2-invokeai;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.invokeai}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/invokeai";
      clientId = "invokeai";
      clientSecretFile = secret "homelab/kanidm/oauth2/invokeai/client-secret";
      cookieSecretFile = secret "homelab/oauth2/invokeai/cookie-secret";
    };

    archerstashvr = {
      port = configVars.networking.ports.tcp.oauth2-archerstashvr;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.archerstashvr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/archerstashvr";
      clientId = "archerstashvr";
      clientSecretFile = secret "homelab/kanidm/oauth2/archerstashvr/client-secret";
      cookieSecretFile = secret "homelab/oauth2/archerstashvr/cookie-secret";
      # Allow VR player access (paths from nix-secrets to avoid exposing API key structure)
      skipAuthRegex = configVars.networking.stash.vrProxyPaths;
    };

    # durin services (9)
    delugeweb = {
      port = configVars.networking.ports.tcp.oauth2-delugeweb;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.delugeweb}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/delugeweb";
      clientId = "delugeweb";
      clientSecretFile = secret "homelab/kanidm/oauth2/delugeweb/client-secret";
      cookieSecretFile = secret "homelab/oauth2/delugeweb/cookie-secret";
      # Pass HTTP Basic Auth to upstream (Deluge requires it)
      # Note: Deluge username is typically in the config, only password from secrets
      basicAuthPasswordFile = secret "deluge-password";
    };

    flood = {
      port = configVars.networking.ports.tcp.oauth2-flood;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.flood}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/flood";
      clientId = "flood";
      clientSecretFile = secret "homelab/kanidm/oauth2/flood/client-secret";
      cookieSecretFile = secret "homelab/oauth2/flood/cookie-secret";
      # Pass HTTP Basic Auth to upstream
      basicAuthUsernameFile = secret "flood-user";
      basicAuthPasswordFile = secret "flood-pass";
    };

    nzbget = {
      port = configVars.networking.ports.tcp.oauth2-nzbget;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.nzbget}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/nzbget";
      clientId = "nzbget";
      clientSecretFile = secret "homelab/kanidm/oauth2/nzbget/client-secret";
      cookieSecretFile = secret "homelab/oauth2/nzbget/cookie-secret";
      # Pass HTTP Basic Auth to upstream (NZBGet requires it)
      basicAuthUsernameFile = secret "homelab/nzbget-durin/username";
      basicAuthPasswordFile = secret "homelab/nzbget-durin/password";
    };

    nzbhydra = {
      port = configVars.networking.ports.tcp.oauth2-nzbhydra;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.nzbhydra}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/nzbhydra";
      clientId = "nzbhydra";
      clientSecretFile = secret "homelab/kanidm/oauth2/nzbhydra/client-secret";
      cookieSecretFile = secret "homelab/oauth2/nzbhydra/cookie-secret";
      # Allow health check endpoint
      skipAuthRegex = [ "^/actuator/health/ping$" ];
    };

    # INACTIVE: Pinchflat is not running anywhere (durin has it disabled) and
    # its estel route is commented out. Kept for when it comes back.
    pinchflat = {
      port = configVars.networking.ports.tcp.oauth2-pinchflat;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.pinchflat}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/pinchflat";
      clientId = "pinchflat";
      clientSecretFile = secret "homelab/kanidm/oauth2/pinchflat/client-secret";
      cookieSecretFile = secret "homelab/oauth2/pinchflat/cookie-secret";
      # Pass HTTP Basic Auth to upstream
      basicAuthUsernameFile = secret "pinchflat/username";
      basicAuthPasswordFile = secret "pinchflat/password";
    };

    radarr = {
      port = configVars.networking.ports.tcp.oauth2-radarr;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.radarr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/radarr";
      clientId = "radarr";
      clientSecretFile = secret "homelab/kanidm/oauth2/radarr/client-secret";
      cookieSecretFile = secret "homelab/oauth2/radarr/cookie-secret";
      # Allow health check endpoint
      skipAuthRegex = [ "^/ping$" ];
      # Pass HTTP Basic Auth to upstream (for API clients)
      basicAuthUsernameFile = secret "homelab/radarr/username";
      basicAuthPasswordFile = secret "homelab/radarr/password";
    };

    sonarr = {
      port = configVars.networking.ports.tcp.oauth2-sonarr;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.sonarr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/sonarr";
      clientId = "sonarr";
      clientSecretFile = secret "homelab/kanidm/oauth2/sonarr/client-secret";
      cookieSecretFile = secret "homelab/oauth2/sonarr/cookie-secret";
      # Allow health check endpoint
      skipAuthRegex = [ "^/ping$" ];
      # Pass HTTP Basic Auth to upstream (for API clients)
      basicAuthUsernameFile = secret "homelab/sonarr/username";
      basicAuthPasswordFile = secret "homelab/sonarr/password";
    };

    stashvr = {
      port = configVars.networking.ports.tcp.oauth2-stashvr;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.stashvr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/stashvr";
      clientId = "stashvr";
      clientSecretFile = secret "homelab/kanidm/oauth2/stashvr/client-secret";
      cookieSecretFile = secret "homelab/oauth2/stashvr/cookie-secret";
      # Allow VR player access (paths from nix-secrets to avoid exposing API key structure)
      skipAuthRegex = configVars.networking.stash.vrProxyPaths;
    };

    whisparr = {
      port = configVars.networking.ports.tcp.oauth2-whisparr;
      upstreamUrl = "http://${configVars.networking.subnets.durin.ip}:${toString configVars.networking.ports.tcp.whisparr}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/whisparr";
      clientId = "whisparr";
      clientSecretFile = secret "homelab/kanidm/oauth2/whisparr/client-secret";
      cookieSecretFile = secret "homelab/oauth2/whisparr/cookie-secret";
      skipAuthRegex = [ "^/ping$" ];
      basicAuthUsernameFile = secret "homelab/whisparr/username";
      basicAuthPasswordFile = secret "homelab/whisparr/password";
    };

    whisparr-eros = {
      port = configVars.networking.ports.tcp.oauth2-whisparr-eros;
      upstreamUrl = "http://${configVars.networking.subnets.smeagol.ip}:${toString configVars.networking.ports.tcp.whisparr-eros}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/whisparr-eros";
      clientId = "whisparr-eros";
      clientSecretFile = secret "homelab/kanidm/oauth2/whisparr-eros/client-secret";
      cookieSecretFile = secret "homelab/oauth2/whisparr-eros/cookie-secret";
      skipAuthRegex = [ "^/ping$" ];
      basicAuthUsernameFile = secret "homelab/whisparr-eros/username";
      basicAuthPasswordFile = secret "homelab/whisparr-eros/password";
    };

    # TubeArchivist logs users in from X-Forwarded-Preferred-Username
    # (TA_LOGIN_AUTH_MODE=forwardauth; see docker/tubearchivist.nix).
    tubearchivist = {
      port = configVars.networking.ports.tcp.oauth2-tubearchivist;
      upstreamUrl = "http://${configVars.networking.subnets.feanor.ip}:${toString configVars.networking.ports.tcp.tubearchivist}";
      oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/tubearchivist";
      clientId = "tubearchivist";
      clientSecretFile = secret "homelab/kanidm/oauth2/tubearchivist/client-secret";
      cookieSecretFile = secret "homelab/oauth2/tubearchivist/cookie-secret";
      # The API authenticates with TubeArchivist tokens (browser extension,
      # other integrations), so it bypasses the login.
      skipAuthRegex = [ "^/api/" ];
    };
  };

in
{
  options.services.homelab-oauth2-proxy.instances = lib.mkOption {
    type = lib.types.listOf (lib.types.enum (builtins.attrNames allInstances));
    default = [ ];
    description = "OAuth2-proxy instances to run on this host.";
  };

  config = lib.mkIf (enabled != [ ]) {
    services.oauth2-proxy-multi.enable = true;
    # Bound to localhost: Caddy on this same host is the only client.
    services.oauth2-proxy-multi.instances = lib.mapAttrs (
      name: inst:
      inst
      // {
        enable = lib.elem name enabled;
        listenAddress = "127.0.0.1";
        # Kanidm matches redirect URIs exactly, so pin the public URL.
        externalUrl =
          let
            base = if lib.elem name homeDomainInstances then configVars.homeDomain else configVars.domain;
          in
          "https://${configVars.networking.subdomains.${name}}.${base}";
        # Only Caddy (localhost) may supply X-Forwarded-* headers.
        extraConfig = (inst.extraConfig or { }) // {
          trusted_proxy_ips = [
            "127.0.0.1/32"
            "::1/128"
          ];
        };
      }
    ) allInstances;

    # Must be readable by the oauth2-proxy user.
    sops.secrets = lib.listToAttrs (
      map (name: {
        inherit name;
        value = {
          owner = config.services.oauth2-proxy-multi.user;
          group = config.services.oauth2-proxy-multi.group;
        };
      }) (lib.unique (lib.concatMap (n: instanceSecrets.${n}) enabled))
    );
  };
}
