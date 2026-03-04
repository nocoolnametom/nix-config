{
  lib,
  configVars,
  config,
  ...
}:
let
  ssoProvider = config.services.ssoProvider.karakeep or "authentik";
  useKanidm = ssoProvider == "kanidm-oidc";
  wellknownURL =
    if useKanidm then
      "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/karakeep/.well-known/openid-configuration"
    else
      "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/karakeep/.well-known/openid-configuration";
in
{
  sops.secrets."homelab/smtp/host" = { };
  sops.secrets."homelab/smtp/port" = { };
  sops.secrets."homelab/smtp/username" = { };
  sops.secrets."homelab/smtp/password" = { };
  sops.secrets."homelab/smtp/sendingDomain" = { };
  sops.secrets."homelab/smtp/ssl" = { };

  # Authentik OIDC secrets
  sops.secrets."homelab/oidc/karakeep/authentik/client-id" = { };
  sops.secrets."homelab/oidc/karakeep/authentik/client-secret" = { };

  # Kanidm OIDC secrets
  sops.secrets."homelab/kanidm/oidc/karakeep/client-secret" = { };
  sops.templates."karakeep-secrets.env" = {
    content =
      ''
        SMTP_HOST=${config.sops.placeholder."homelab/smtp/host"}
        SMTP_PORT=${config.sops.placeholder."homelab/smtp/port"}
        SMTP_SECURE=${config.sops.placeholder."homelab/smtp/ssl"}
        SMTP_USER=${config.sops.placeholder."homelab/smtp/username"}
        SMTP_PASSWORD=${config.sops.placeholder."homelab/smtp/password"}
        SMTP_FROM=no-reply+karakeep@${config.sops.placeholder."homelab/smtp/sendingDomain"}
      ''
      + (
        if useKanidm then
          ''
            OAUTH_CLIENT_ID=karakeep
            OAUTH_CLIENT_SECRET=${config.sops.placeholder."homelab/kanidm/oidc/karakeep/client-secret"}
          ''
        else
          ''
            OAUTH_CLIENT_ID=${config.sops.placeholder."homelab/oidc/karakeep/authentik/client-id"}
            OAUTH_CLIENT_SECRET=${config.sops.placeholder."homelab/oidc/karakeep/authentik/client-secret"}
          ''
      );
    owner = if config.services.karakeep.enable then "karakeep" else "root";
  };
  services.karakeep.enable = lib.mkDefault true;
  services.karakeep.browser.enable = lib.mkDefault true;
  services.karakeep.meilisearch.enable = lib.mkDefault true;
  services.karakeep.environmentFile = lib.mkDefault config.sops.templates."karakeep-secrets.env".path;
  services.karakeep.extraEnvironment.PORT = builtins.toString configVars.networking.ports.tcp.karakeep;
  services.karakeep.extraEnvironment.DISABLE_PASSWORD_AUTH = "true";
  services.karakeep.extraEnvironment.DISABLE_NEW_RELEASE_CHECK = "true";
  services.karakeep.extraEnvironment.NEXTAUTH_URL = "https://${configVars.networking.subdomains.karakeep}.${configVars.homeDomain}";
  services.karakeep.extraEnvironment.OAUTH_WELLKNOWN_URL = wellknownURL;
  services.karakeep.extraEnvironment.OAUTH_PROVIDER_NAME = if useKanidm then "Kanidm" else "authentik";
  services.karakeep.extraEnvironment.OAUTH_ALLOW_DANGEROUS_EMAIL_ACCOUNT_LINKIN = "true";
  services.karakeep.extraEnvironment.OLLAMA_BASE_URL = "http://${configVars.networking.subnets.smeagol.ip}:${builtins.toString configVars.networking.ports.tcp.ollama}";
  services.karakeep.extraEnvironment.OLLAMA_KEEP_ALIVE = "5m";
  services.karakeep.extraEnvironment.INFERENCE_TEXT_MODEL = "llama3.2:latest";
  services.karakeep.extraEnvironment.INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";
}
