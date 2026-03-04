{
  lib,
  config,
  configVars,
  ...
}:
let
  ssoProvider = config.services.ssoProvider.mealie or "authentik";
  useKanidm = ssoProvider == "kanidm-oidc";
in
{
  sops.secrets."homelab/smtp/host" = { };
  sops.secrets."homelab/smtp/port" = { };
  sops.secrets."homelab/smtp/username" = { };
  sops.secrets."homelab/smtp/password" = { };
  sops.secrets."homelab/smtp/sendingDomain" = { };

  # Authentik OIDC secrets
  sops.secrets."homelab/oidc/mealie/authentik/client-id" = { };
  sops.secrets."homelab/oidc/mealie/authentik/client-secret" = { };

  # Kanidm OIDC secrets
  sops.secrets."homelab/kanidm/oidc/mealie/client-secret" = { };

  services.mealie.enable = lib.mkDefault true;
  services.mealie.port = lib.mkDefault configVars.networking.ports.tcp.mealie;
  services.mealie.database.createLocally = lib.mkDefault true;
  services.mealie.settings = lib.mkDefault (
    {
      BASE_URL = "https://${configVars.networking.subdomains.mealie}.${configVars.homeDomain}";
      ALLOW_PASSWORD_LOGIN = "true"; # Turn off once OIDC is confirmed working!
      OIDC_AUTH_ENABLED = "true";
      OIDC_SIGNUP_ENABLED = "true";
      OIDC_AUTO_REDIRECT = "true";
      OIDC_REMEMBER_ME = "true";
      OPENAI_BASE_URL = "http://${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.ollama}/v1";
      OPENAI_API_KEY = "1234567890123456"; # Ollama doesn't care about api keys
      OPENAI_MODEL = "llama3.2:latest";
      OPENAI_ENABLE_IMAGE_SERVICES = "false";
      OPENAI_REQUEST_TIMEOUT = "180";
    }
    // (
      if useKanidm then
        {
          # Kanidm OIDC configuration
          OIDC_PROVIDER_NAME = "Kanidm";
          OIDC_CONFIGURATION_URL = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/mealie/.well-known/openid-configuration";
          OIDC_USER_GROUP = "service_users";
          OIDC_ADMIN_GROUP = "kanidm_admins";
        }
      else
        {
          # Authentik OIDC configuration
          OIDC_PROVIDER_NAME = "authentik";
          OIDC_CONFIGURATION_URL = "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/mealie/.well-known/openid-configuration";
          OIDC_USER_GROUP = "mealie-users";
          OIDC_ADMIN_GROUP = "mealie-admins";
        }
    )
  );
  sops.templates."mealie-secrets.env" = {
    content =
      ''
        SMTP_HOST=${config.sops.placeholder."homelab/smtp/host"}
        SMTP_PORT=${config.sops.placeholder."homelab/smtp/port"}
        SMTP_FROM_NAME=Mealie
        SMTP_AUTH_STRATEGY=SSL
        SMTP_FROM_EMAIL=noreply+mealie@${config.sops.placeholder."homelab/smtp/sendingDomain"}
        SMTP_USER=${config.sops.placeholder."homelab/smtp/username"}
        SMTP_PASSWORD=${config.sops.placeholder."homelab/smtp/password"}
      ''
      + (
        if useKanidm then
          ''
            OIDC_CLIENT_ID=mealie
            OIDC_CLIENT_SECRET=${config.sops.placeholder."homelab/kanidm/oidc/mealie/client-secret"}
          ''
        else
          ''
            OIDC_CLIENT_ID=${config.sops.placeholder."homelab/oidc/mealie/authentik/client-id"}
            OIDC_CLIENT_SECRET=${config.sops.placeholder."homelab/oidc/mealie/authentik/client-secret"}
          ''
      );
  };
  services.mealie.credentialsFile = lib.mkDefault config.sops.templates."mealie-secrets.env".path;
}
