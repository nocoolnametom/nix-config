{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
{
  sops.secrets."homelab/smtp/host" = { };
  sops.secrets."homelab/smtp/port" = { };
  sops.secrets."homelab/smtp/username" = { };
  sops.secrets."homelab/smtp/password" = { };
  sops.secrets."homelab/smtp/sendingDomain" = { };
  sops.secrets."homelab/smtp/ssl" = { };
  sops.secrets."homelab/smtp/tls" = { };
  sops.secrets."paperless-superuser-password".owner = config.services.paperless.user;
  sops.secrets."homelab/oidc/paperless/authentik/client-id" = { };
  sops.secrets."homelab/oidc/paperless/authentik/client-secret" = { };

  services.paperless.enable = lib.mkDefault true;
  services.paperless.port = lib.mkDefault configVars.networking.ports.tcp.paperless;
  services.paperless.configureTika = lib.mkDefault true;
  services.gotenberg = {
    package = pkgs.gotenberg;
    libreoffice.package = pkgs.libreoffice;
    chromium.package = pkgs.chromium;
  };
  services.paperless.database.createLocally = true;
  services.paperless.passwordFile =
    lib.mkDefault
      config.sops.secrets."paperless-superuser-password".path;
  services.paperless.settings.PAPERLESS_ENABLE_ALLAUTH = lib.mkDefault "true";
  services.paperless.settings.PAPERLESS_APPS = lib.mkDefault "allauth.socialaccount.providers.openid_connect";
  services.paperless.settings.PAPERLESS_URL = lib.mkDefault "https://${configVars.networking.subdomains.paperless}.${configVars.homeDomain}";

  sops.templates."paperless-secrets.env" = {
    # We have to declare the entire OIDC configuration in the secrets file, unfortunately
    content = ''
      PAPERLESS_EMAIL_HOST=${config.sops.placeholder."homelab/smtp/host"}
      PAPERLESS_EMAIL_PORT=${config.sops.placeholder."homelab/smtp/port"}
      PAPERLESS_EMAIL_HOST_USER=${config.sops.placeholder."homelab/smtp/username"}
      PAPERLESS_EMAIL_HOST_PASSWORD=${config.sops.placeholder."homelab/smtp/password"}
      PAPERLESS_EMAIL_FROM=noreply+papers@${config.sops.placeholder."homelab/smtp/sendingDomain"}
      PAPERLESS_EMAIL_USE_SSL=${config.sops.placeholder."homelab/smtp/ssl"}
      PAPERLESS_EMAIL_USE_TLS=${config.sops.placeholder."homelab/smtp/tls"}
      PAPERLESS_SOCIALACCOUNT_PROVIDERS=${
        builtins.toJSON {
          openid_connect = {
            OAUTH_PKCE_ENABLED = true;
            APPS = [
              {
                provider_id = "authentik";
                name = "authentik";
                client_id = config.sops.placeholder."homelab/oidc/paperless/authentik/client-id";
                secret = config.sops.placeholder."homelab/oidc/paperless/authentik/client-secret";
                settings = {
                  server_url = "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/paperless/.well-known/openid-configuration";
                };
              }
            ];
          };
        }
      }
    '';
  };
  services.paperless.environmentFile =
    lib.mkDefault
      config.sops.templates."paperless-secrets.env".path;
}
