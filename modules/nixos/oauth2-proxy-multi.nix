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

        upstreamUrl = mkOption {
          type = types.str;
          description = "URL of the upstream service (e.g., 'http://192.168.0.30:4533')";
        };

        oidcIssuerUrl = mkOption {
          type = types.str;
          description = "OIDC issuer URL (e.g., 'https://sso.doggett.family')";
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

        # Proxy behavior
        skipAuthRegex = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Bypass OAuth for requests matching these regexes";
          example = [ "^/public/" "^/health$" ];
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

  # Generate configuration file for an instance
  mkInstanceConfig = name: instCfg:
    let
      baseConfig = {
        http_address = "0.0.0.0:${toString instCfg.port}";
        upstreams = [ instCfg.upstreamUrl ];
        provider = "oidc";
        oidc_issuer_url = instCfg.oidcIssuerUrl;
        client_id = instCfg.clientId;
        email_domains = instCfg.emailDomains;
        cookie_secure = instCfg.cookieSecure;
        cookie_httponly = instCfg.cookieHttpOnly;
        cookie_name = instCfg.cookieName;
        set_xauthrequest = instCfg.setXAuthRequest;
        pass_access_token = instCfg.passAccessToken;
        pass_user_headers = instCfg.passUserHeaders;
        pass_basic_auth = instCfg.passBasicAuth;
        set_authorization_header = instCfg.setAuthorizationHeader;
        reverse_proxy = instCfg.reverseProxy;
      } // (optionalAttrs (instCfg.basicAuthPassword != null) { basic_auth_password = instCfg.basicAuthPassword; }) // (optionalAttrs (instCfg.skipAuthRegex != [ ]) { skip_auth_regex = instCfg.skipAuthRegex; }) // instCfg.extraConfig;

      configLines = mapAttrsToList (
        k: v:
        if isList v then
          map (item: ''${k} = "${item}"'') v
        else if isBool v then
          "${k} = ${if v then "true" else "false"}"
        else
          ''${k} = "${toString v}"''
      ) baseConfig;

      flatConfigLines = flatten configLines;
    in
    pkgs.writeText "oauth2-proxy-${name}.cfg" (concatStringsSep "\n" flatConfigLines);

  # Create systemd service for an instance
  mkInstanceService = name: instCfg: {
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

        ExecStart = ''
          ${pkgs.oauth2-proxy}/bin/oauth2-proxy \
            --config ${mkInstanceConfig name instCfg} \
            --client-secret-file ${instCfg.clientSecretFile} \
            --cookie-secret-file ${instCfg.cookieSecretFile}
        '';

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

    # Create systemd services for all enabled instances
    systemd.services = listToAttrs (mapAttrsToList mkInstanceService enabledInstances);
  };
}
