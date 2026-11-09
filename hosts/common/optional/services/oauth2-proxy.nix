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
    "open-resume"
  ];
  secret = name: config.sops.secrets.${name}.path;

  # Common OIDC fields shared by all instances (derived from instance name).
  oidcFields = name: {
    oidcIssuerUrl = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/${name}";
    clientId = name;
    clientSecretFile = secret "homelab/kanidm/oauth2/${name}/client-secret";
    cookieSecretFile = secret "homelab/oauth2/${name}/cookie-secret";
  };

  # All instances share the same OIDC secret pattern.
  allInstanceNames = [
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
    "open-resume"
    "pinchflat"
    "radarr"
    "sonarr"
    "stashvr"
    "whisparr"
    "whisparr-eros"
    "tubearchivist"
  ];

  # Base secrets for every instance (Kanidm client secret + cookie secret).
  baseSecrets = name: [
    "homelab/kanidm/oauth2/${name}/client-secret"
    "homelab/oauth2/${name}/cookie-secret"
  ];

  # Additional upstream basic-auth secrets (instances without these use []).
  extraSecrets = {
    delugeweb = [ "deluge-password" ];
    flood = [
      "flood-user"
      "flood-pass"
    ];
    nzbget = [
      "homelab/nzbget-durin/username"
      "homelab/nzbget-durin/password"
    ];
    pinchflat = [
      "pinchflat/username"
      "pinchflat/password"
    ];
    radarr = [
      "homelab/radarr/username"
      "homelab/radarr/password"
    ];
    sonarr = [
      "homelab/sonarr/username"
      "homelab/sonarr/password"
    ];
    whisparr = [
      "homelab/whisparr/username"
      "homelab/whisparr/password"
    ];
    whisparr-eros = [
      "homelab/whisparr-eros/username"
      "homelab/whisparr-eros/password"
    ];
  };

  # Total secrets for an instance = base + extras (if any).
  instanceSecrets = lib.genAttrs allInstanceNames (
    name: baseSecrets name ++ (extraSecrets.${name} or [ ])
  );

  # Build an instance config from name + host + overrides.
  # Derives port (oauth2-<name>), upstreamUrl (http://<host>:<name>), and OIDC fields.
  makeInstance =
    name: host: overrides:
    (oidcFields name)
    // {
      port = configVars.networking.ports.tcp.${"oauth2-" + name};
      upstreamUrl = "http://${configVars.networking.subnets.${host}.ip}:${
        toString configVars.networking.ports.tcp.${name}
      }";
    }
    // overrides;

  allInstances = {
    # estel services (2)
    navidrome = makeInstance "navidrome" "feanor" {
      # Navidrome runs on feanor (navidrome.nix) and trusts the username
      # header only from estel, where this instance runs.
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

    seerr = makeInstance "seerr" "estel" {
      # Allow API access for Plex/Jellyfin integration and mobile apps
      skipAuthRegex = [ "^/api/.*" ];
    };

    # smeagol services (5)
    comfyui = makeInstance "comfyui" "smeagol" { };
    comfyuimini = makeInstance "comfyuimini" "smeagol" { };
    invokeai = makeInstance "invokeai" "smeagol" { };
    archerstashvr = makeInstance "archerstashvr" "smeagol" {
      # Allow VR player access (paths from nix-secrets to avoid exposing API key structure)
      skipAuthRegex = configVars.networking.stash.vrProxyPaths;
    };
    whisparr-eros = makeInstance "whisparr-eros" "smeagol" {
      skipAuthRegex = [ "^/ping$" ];
      basicAuthUsernameFile = secret "homelab/whisparr-eros/username";
      basicAuthPasswordFile = secret "homelab/whisparr-eros/password";
    };

    # feanor services (3)
    open-resume = makeInstance "open-resume" "feanor" { };
    tubearchivist = makeInstance "tubearchivist" "feanor" {
      # The API authenticates with TubeArchivist tokens (browser extension,
      # other integrations), so it bypasses the login.
      skipAuthRegex = [ "^/api/" ];
    };

    # durin services (9)
    delugeweb = makeInstance "delugeweb" "durin" {
      # Pass HTTP Basic Auth to upstream (Deluge requires it)
      basicAuthPasswordFile = secret "deluge-password";
    };
    flood = makeInstance "flood" "durin" {
      # Pass HTTP Basic Auth to upstream
      basicAuthUsernameFile = secret "flood-user";
      basicAuthPasswordFile = secret "flood-pass";
    };
    nzbget = makeInstance "nzbget" "durin" {
      # Pass HTTP Basic Auth to upstream (NZBGet requires it)
      basicAuthUsernameFile = secret "homelab/nzbget-durin/username";
      basicAuthPasswordFile = secret "homelab/nzbget-durin/password";
      skipAuthRegex = [ "^/jsonrpc$" ];
    };
    nzbhydra = makeInstance "nzbhydra" "durin" {
      # Allow health check endpoint
      skipAuthRegex = [ "^/actuator/health/ping$" ];
    };
    # INACTIVE: Pinchflat is not running anywhere (durin has it disabled) and
    # its estel route is commented out. Kept for when it comes back.
    pinchflat = makeInstance "pinchflat" "durin" {
      # Pass HTTP Basic Auth to upstream
      basicAuthUsernameFile = secret "pinchflat/username";
      basicAuthPasswordFile = secret "pinchflat/password";
    };
    radarr = makeInstance "radarr" "durin" {
      skipAuthRegex = [ "^/ping$" ];
      basicAuthUsernameFile = secret "homelab/radarr/username";
      basicAuthPasswordFile = secret "homelab/radarr/password";
    };
    sonarr = makeInstance "sonarr" "durin" {
      skipAuthRegex = [ "^/ping$" ];
      basicAuthUsernameFile = secret "homelab/sonarr/username";
      basicAuthPasswordFile = secret "homelab/sonarr/password";
    };
    stashvr = makeInstance "stashvr" "durin" {
      # Allow VR player access (paths from nix-secrets to avoid exposing API key structure)
      skipAuthRegex = configVars.networking.stash.vrProxyPaths;
    };
    whisparr = makeInstance "whisparr" "durin" {
      skipAuthRegex = [ "^/ping$" ];
      basicAuthUsernameFile = secret "homelab/whisparr/username";
      basicAuthPasswordFile = secret "homelab/whisparr/password";
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
