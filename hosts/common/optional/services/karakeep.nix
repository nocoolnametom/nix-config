{
  lib,
  configVars,
  config,
  ...
}:
{
  sops.secrets."homelab/smtp/host" = { };
  sops.secrets."homelab/smtp/port" = { };
  sops.secrets."homelab/smtp/username" = { };
  sops.secrets."homelab/smtp/password" = { };
  sops.secrets."homelab/smtp/sendingDomain" = { };
  sops.secrets."homelab/smtp/ssl" = { };
  sops.secrets."homelab/oidc/karakeep/authentik/client-id" = { };
  sops.secrets."homelab/oidc/karakeep/authentik/client-secret" = { };
  sops.templates."karakeep-secrets.env" = {
    content = ''
      SMTP_HOST=${config.sops.placeholder."homelab/smtp/host"}
      SMTP_PORT=${config.sops.placeholder."homelab/smtp/port"}
      SMTP_SECURE=${config.sops.placeholder."homelab/smtp/ssl"}
      SMTP_USER=${config.sops.placeholder."homelab/smtp/username"}
      SMTP_PASSWORD=${config.sops.placeholder."homelab/smtp/password"}
      SMTP_FROM=no-reply+karakeep@${config.sops.placeholder."homelab/smtp/sendingDomain"}
      OAUTH_CLIENT_ID=${config.sops.placeholder."homelab/oidc/karakeep/authentik/client-id"} 
      OAUTH_CLIENT_SECRET=${config.sops.placeholder."homelab/oidc/karakeep/authentik/client-secret"} 
    '';
    owner = "karakeep";
  };
  services.karakeep.enable = lib.mkDefault true;
  services.karakeep.browser.enable = lib.mkDefault true;
  services.karakeep.meilisearch.enable = lib.mkDefault true;
  services.karakeep.environmentFile = lib.mkDefault config.sops.templates."karakeep-secrets.env".path;
  services.karakeep.extraEnvironment.PORT = builtins.toString configVars.networking.ports.tcp.karakeep;
  services.karakeep.extraEnvironment.DISABLE_PASSWORD_AUTH= "true";
  services.karakeep.extraEnvironment.DISABLE_NEW_RELEASE_CHECK = "true";
  services.karakeep.extraEnvironment.NEXTAUTH_URL = "https://${configVars.networking.subdomains.karakeep}.${configVars.homeDomain}";
  services.karakeep.extraEnvironment.OAUTH_WELLKNOWN_URL = "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/karakeep/.well-known/openid-configuration";
  services.karakeep.extraEnvironment.OAUTH_PROVIDER_NAME = "authentik";
  services.karakeep.extraEnvironment.OAUTH_ALLOW_DANGEROUS_EMAIL_ACCOUNT_LINKIN = "true";
  services.karakeep.extraEnvironment.OLLAMA_BASE_URL = "http://${configVars.networking.subnets.archer.ip}:${builtins.toString configVars.networking.ports.tcp.ollama}";
  services.karakeep.extraEnvironment.OLLAMA_KEEP_ALIVE = "5m";
  services.karakeep.extraEnvironment.INFERENCE_TEXT_MODEL = "llama3.2:latest";
  services.karakeep.extraEnvironment.INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";
}
