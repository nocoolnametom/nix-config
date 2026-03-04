{
  pkgs,
  lib,
  configVars,
  config,
  ...
}:
let
  ssoProvider = config.services.ssoProvider.miniflux or "authentik";
  useKanidm = ssoProvider == "kanidm-oidc";
in
{
  # PostgreSQL database for Miniflux
  services.postgresql.enable = lib.mkDefault true;
  services.postgresql.ensureDatabases = [ "miniflux" ];
  services.postgresql.ensureUsers = [
    {
      name = "miniflux";
      ensureDBOwnership = true;
    }
  ];

  # Miniflux RSS reader service
  services.miniflux.enable = lib.mkDefault true;
  services.miniflux.createDatabaseLocally = true;

  # Miniflux configuration
  # Documentation: https://miniflux.app/docs/configuration.html
  services.miniflux.config = lib.mkDefault (
    {
      # Basic settings
      LISTEN_ADDR = "0.0.0.0:${toString configVars.networking.ports.tcp.miniflux}";
      BASE_URL = "https://${configVars.networking.subdomains.miniflux}.${configVars.homeDomain}";

      # Database is automatically configured by createDatabaseLocally

      # Enable WebAuthn/Passkey authentication
      WEBAUTHN = "1";

      # OAuth2/OIDC settings
      OAUTH2_PROVIDER = "oidc";
      OAUTH2_USER_CREATION = "1"; # Auto-create users from OIDC
      OAUTH2_REDIRECT_URL = "https://${configVars.networking.subdomains.miniflux}.${configVars.homeDomain}/oauth2/callback";

      # Cleanup and performance settings
      CLEANUP_FREQUENCY = "48"; # Cleanup every 48 hours
      CLEANUP_ARCHIVE_READ_DAYS = "60"; # Archive read items after 60 days
    }
    // (
      if useKanidm then
        {
          # Kanidm OIDC configuration
          OAUTH2_OIDC_PROVIDER_NAME = "Kanidm";
          # Note: Miniflux automatically appends .well-known/openid-configuration
          OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/miniflux/";
        }
      else
        {
          # Authentik OIDC configuration
          OAUTH2_OIDC_PROVIDER_NAME = "Authentik";
          OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/miniflux/";
        }
    )
  );

  # Admin credentials (required for initial setup)
  sops.secrets."homelab/miniflux/admin-credentials" = { };
  services.miniflux.adminCredentialsFile = config.sops.secrets."homelab/miniflux/admin-credentials".path;

  # Authentik OIDC secrets
  sops.secrets."homelab/oidc/miniflux/authentik/client-id" = { };
  sops.secrets."homelab/oidc/miniflux/authentik/client-secret" = { };

  # Kanidm OIDC secrets
  sops.secrets."homelab/kanidm/oidc/miniflux/client-secret" = { };

  # Environment file with OIDC credentials
  sops.templates."miniflux-secrets.env" =
    {
      content = if useKanidm then
        ''
          OAUTH2_CLIENT_ID=miniflux
          OAUTH2_CLIENT_SECRET=${config.sops.placeholder."homelab/kanidm/oidc/miniflux/client-secret"}
        ''
      else
        ''
          OAUTH2_CLIENT_ID=${config.sops.placeholder."homelab/oidc/miniflux/authentik/client-id"}
          OAUTH2_CLIENT_SECRET=${config.sops.placeholder."homelab/oidc/miniflux/authentik/client-secret"}
        '';
      owner = config.systemd.services.miniflux.serviceConfig.User;
    };

  # Pass secrets to Miniflux via environment file
  systemd.services.miniflux.serviceConfig.EnvironmentFile = [
    config.sops.templates."miniflux-secrets.env".path
  ];

  # Open firewall port
  networking.firewall.allowedTCPPorts = [ configVars.networking.ports.tcp.miniflux ];
}
