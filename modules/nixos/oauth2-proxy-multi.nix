{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.oauth2-proxy-multi;

  # Instance type definition
  instanceType = types.submodule (
    { name, ... }:
    {
      options = {
        enable = mkEnableOption "this oauth2-proxy instance" // {
          default = true;
        };

        port = mkOption {
          type = types.port;
          description = "Port for this instance to listen on";
        };

        listenAddress = mkOption {
          type = types.str;
          default = "0.0.0.0";
          description = "Address to bind; use 127.0.0.1 when the reverse proxy is on the same host.";
        };

        upstreamUrl = mkOption {
          type = types.str;
          description = "URL of the upstream service (e.g., 'http://192.168.0.30:4533')";
        };

        oidcIssuerUrl = mkOption {
          type = types.str;
          description = "OIDC issuer URL (e.g., 'https://sso.example.com')";
        };

        clientId = mkOption {
          type = types.str;
          description = "OAuth2 client ID";
        };

        clientSecretFile = mkOption {
          type = types.path;
          description = "Path to OAuth2 client secret file";
        };

        cookieSecretFile = mkOption {
          type = types.path;
          description = "Path to cookie secret file (must be 16, 24, or 32 bytes when base64 decoded)";
        };

        emailDomains = mkOption {
          type = types.listOf types.str;
          default = [ "*" ];
          description = "Allowed email domains. Use ['*'] to allow any authenticated user.";
        };

        # Header injection options
        setXAuthRequest = mkOption {
          type = types.bool;
          default = true;
          description = "Set X-Auth-Request-User, X-Auth-Request-Email, X-Auth-Request-Preferred-Username headers";
        };

        passAccessToken = mkOption {
          type = types.bool;
          default = true;
          description = "Pass OAuth access token to upstream via X-Forwarded-Access-Token header";
        };

        passUserHeaders = mkOption {
          type = types.bool;
          default = true;
          description = "Pass X-Forwarded-User, X-Forwarded-Email, X-Forwarded-Preferred-Username headers to upstream";
        };

        passBasicAuth = mkOption {
          type = types.bool;
          default = false;
          description = "Pass HTTP Basic Auth to application with X-Forwarded-User as username";
        };

        basicAuthPassword = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Password to use for HTTP Basic Auth when passBasicAuth is enabled";
        };

        basicAuthUsernameFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to file containing HTTP Basic Auth username (for custom credentials)";
        };

        basicAuthPasswordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Path to file containing HTTP Basic Auth password (for custom credentials)";
        };

        setAuthorizationHeader = mkOption {
          type = types.bool;
          default = false;
          description = "Set Authorization header with Bearer token";
        };

        # Additional header customization
        extraHeaders = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = ''
            Extra headers to inject into requests to upstream.
            Example: { "X-Custom-Header" = "value"; }
          '';
          example = {
            "X-Auth-Request-Groups" = "{{ .Groups }}";
            "X-Custom-User" = "{{ .User }}";
          };
        };

        # Cookie settings
        cookieSecure = mkOption {
          type = types.bool;
          default = true;
          description = "Set secure flag on cookies";
        };

        cookieHttpOnly = mkOption {
          type = types.bool;
          default = true;
          description = "Set HttpOnly flag on cookies";
        };

        cookieName = mkOption {
          type = types.str;
          default = "_oauth2_proxy";
          description = "Name of the OAuth2 cookie";
        };

        externalUrl = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "https://app.example.com";
          description = ''
            Public URL users reach this instance at. Sets redirect_url to
            <externalUrl>/oauth2/callback. Providers that match redirect URIs
            exactly (e.g. Kanidm) need this; otherwise oauth2-proxy derives it
            from request headers.
          '';
        };

        codeChallengeMethod = mkOption {
          type = types.nullOr (
            types.enum [
              "S256"
              "plain"
            ]
          );
          default = "S256";
          description = "PKCE method sent to the provider (null disables PKCE).";
        };

        openFirewall = mkOption {
          type = types.bool;
          default = false;
          description = "Open this instance's port (e.g. for a reverse proxy on another host).";
        };

        # Proxy behavior
        skipAuthRegex = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Bypass OAuth for requests matching these regexes";
          example = [
            "^/public/"
            "^/health$"
          ];
        };

        reverseProxy = mkOption {
          type = types.bool;
          default = true;
          description = "Trust X-Forwarded-* headers from reverse proxy";
        };

        # Additional OAuth2-proxy configuration
        extraConfig = mkOption {
          type = types.attrs;
          default = { };
          description = "Additional configuration options to pass to oauth2-proxy";
        };
      };
    }
  );

  # Get enabled instances
  enabledInstances = filterAttrs (n: v: v.enable) cfg.instances;

  # Each instance runs with oauth2-proxy's structured ("alpha") config, which
  # owns the server address, upstream, provider and all header injection.
  # The legacy config file is limited to what alpha mode still accepts
  # (cookies, skip-auth rules, redirect URL, trusted proxies, email domains);
  # options alpha mode replaces are an error if left in it.
  mkLegacyConfig =
    name: instCfg:
    let
      baseConfig = {
        email_domains = instCfg.emailDomains;
        cookie_secure = instCfg.cookieSecure;
        cookie_httponly = instCfg.cookieHttpOnly;
        cookie_name = instCfg.cookieName;
        reverse_proxy = instCfg.reverseProxy;
      }
      // (optionalAttrs (instCfg.skipAuthRegex != [ ]) { skip_auth_regex = instCfg.skipAuthRegex; })
      // (optionalAttrs (instCfg.externalUrl != null) {
        redirect_url = "${instCfg.externalUrl}/oauth2/callback";
      })
      // instCfg.extraConfig;

      # TOML: lists must be arrays (repeating a key is a parse error), and
      # JSON string/array syntax is valid TOML with the same escaping, which
      # matters for regexes containing backslashes.
      configLines = mapAttrsToList (
        k: v:
        if isList v then
          "${k} = ${builtins.toJSON v}"
        else if isBool v then
          "${k} = ${if v then "true" else "false"}"
        else
          "${k} = ${builtins.toJSON (toString v)}"
      ) baseConfig;
    in
    pkgs.writeText "oauth2-proxy-${name}.cfg" (concatStringsSep "\n" configLines);

  runtimeDir = name: "/run/oauth2-proxy-${name}";
  hasStaticBasicAuth =
    instCfg: instCfg.basicAuthUsernameFile != null && instCfg.basicAuthPasswordFile != null;

  claimHeader = header: claim: {
    name = header;
    values = [ { claimSource = { inherit claim; }; } ];
  };

  # JSON is valid YAML, so the alpha config is generated with toJSON.
  mkAlphaConfig =
    name: instCfg:
    let
      requestHeaders =
        optionals instCfg.passUserHeaders [
          (claimHeader "X-Forwarded-User" "user")
          (claimHeader "X-Forwarded-Email" "email")
          (claimHeader "X-Forwarded-Preferred-Username" "preferred_username")
          (claimHeader "X-Forwarded-Groups" "groups")
        ]
        ++ optional instCfg.passAccessToken (claimHeader "X-Forwarded-Access-Token" "access_token")
        # Static upstream credentials, only ever sent after a successful login.
        # The file is written at service start from the sops secrets.
        ++ optional (hasStaticBasicAuth instCfg) {
          name = "Authorization";
          values = [ { secretSource.fromFile = "${runtimeDir name}/upstream-authorization"; } ];
        };

      responseHeaders =
        optionals instCfg.setXAuthRequest [
          (claimHeader "X-Auth-Request-User" "user")
          (claimHeader "X-Auth-Request-Email" "email")
          (claimHeader "X-Auth-Request-Preferred-Username" "preferred_username")
          (claimHeader "X-Auth-Request-Groups" "groups")
        ]
        ++ optional instCfg.setAuthorizationHeader {
          name = "Authorization";
          values = [
            {
              claimSource = {
                claim = "id_token";
                prefix = "Bearer ";
              };
            }
          ];
        };
    in
    pkgs.writeText "oauth2-proxy-${name}.alpha.yaml" (
      builtins.toJSON (
        {
          server.bindAddress = "http://${instCfg.listenAddress}:${toString instCfg.port}";
          upstreamConfig.upstreams = [
            {
              id = name;
              path = "/";
              uri = instCfg.upstreamUrl;
            }
          ];
          providers = [
            (
              {
                id = "oidc";
                provider = "oidc";
                clientID = instCfg.clientId;
                clientSecretFile = instCfg.clientSecretFile;
                scope = "openid email profile";
                oidcConfig.issuerURL = instCfg.oidcIssuerUrl;
              }
              // optionalAttrs (instCfg.codeChallengeMethod != null) {
                code_challenge_method = instCfg.codeChallengeMethod;
              }
            )
          ];
        }
        // optionalAttrs (requestHeaders != [ ]) { injectRequestHeaders = requestHeaders; }
        // optionalAttrs (responseHeaders != [ ]) { injectResponseHeaders = responseHeaders; }
      )
    );

  # Create systemd service for an instance
  mkInstanceService =
    name: instCfg:
    let
      startScript = pkgs.writeShellScript "oauth2-proxy-${name}-start" ''
        set -euo pipefail
        ${optionalString (hasStaticBasicAuth instCfg) ''
          umask 077
          user=$(cat ${instCfg.basicAuthUsernameFile})
          pass=$(cat ${instCfg.basicAuthPasswordFile})
          printf 'Basic %s' "$(printf '%s:%s' "$user" "$pass" | ${pkgs.coreutils}/bin/base64 -w 0)" \
            > "$RUNTIME_DIRECTORY/upstream-authorization"
          unset user pass
        ''}
        exec ${pkgs.oauth2-proxy}/bin/oauth2-proxy \
          --alpha-config ${mkAlphaConfig name instCfg} \
          --config ${mkLegacyConfig name instCfg} \
          --cookie-secret-file ${instCfg.cookieSecretFile}
      '';
    in
    {
      name = "oauth2-proxy-${name}";
      value = {
        description = "OAuth2 Proxy for ${name}";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = "5s";
          User = cfg.user;
          Group = cfg.group;

          ExecStart = startScript;
          # Holds the rendered upstream Authorization header, if any.
          RuntimeDirectory = "oauth2-proxy-${name}";
          RuntimeDirectoryMode = "0700";

          # Security hardening
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectClock = true;
          ProtectHostname = true;
        };
      };
    };

in
{
  options.services.oauth2-proxy-multi = {
    enable = mkEnableOption "OAuth2 Proxy Multi-Instance service";

    user = mkOption {
      type = types.str;
      default = "oauth2-proxy";
      description = "User account for oauth2-proxy instances";
    };

    group = mkOption {
      type = types.str;
      default = "oauth2-proxy";
      description = "Group for oauth2-proxy instances";
    };

    instances = mkOption {
      type = types.attrsOf instanceType;
      default = { };
      description = "OAuth2-proxy instances to run";
      example = literalExpression ''
        {
          myservice = {
            port = 4180;
            upstreamUrl = "http://localhost:8080";
            oidcIssuerUrl = "https://sso.example.com";
            clientId = "myservice";
            clientSecretFile = "/run/secrets/oauth2-client-secret";
            cookieSecretFile = "/run/secrets/oauth2-cookie-secret";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "OAuth2 Proxy service user";
      extraGroups = [ "keys" ]; # Need access to SOPS secrets
    };

    users.groups.${cfg.group} = { };

    assertions = mapAttrsToList (name: i: {
      assertion = !i.passBasicAuth;
      message = "oauth2-proxy-multi.${name}: passBasicAuth is not supported in alpha-config mode; use basicAuthUsernameFile/basicAuthPasswordFile.";
    }) enabledInstances;

    # Create systemd services for all enabled instances
    systemd.services = listToAttrs (mapAttrsToList mkInstanceService enabledInstances);

    networking.firewall.allowedTCPPorts = mapAttrsToList (_: i: i.port) (
      filterAttrs (_: i: i.openFirewall) enabledInstances
    );
  };
}
