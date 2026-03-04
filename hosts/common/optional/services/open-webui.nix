{
  lib,
  pkgs,
  config,
  configVars,
  ...
}:
let
  ssoProvider = config.services.ssoProvider.openwebui or "authentik";
  useKanidm = ssoProvider == "kanidm-oidc";
in
{
  services.open-webui.enable = lib.mkDefault true;
  services.open-webui.host = lib.mkDefault "0.0.0.0";
  services.open-webui.port = lib.mkDefault configVars.networking.ports.tcp.openwebui;
  services.open-webui.openFirewall = lib.mkDefault true;

  # Authentik OIDC secrets
  sops.secrets."open-webui-slug" = { };
  sops.secrets."open-webui-clientid" = { };
  sops.secrets."open-webui-clientsecret" = { };

  # Kanidm OIDC secrets
  sops.secrets."homelab/kanidm/oidc/openwebui/client-secret" = { };
  sops.templates."open-webui.conf".content =
    if useKanidm then
      ''
        ENABLE_OAUTH_SIGNUP=true
        OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
        OAUTH_PROVIDER_NAME=Kanidm
        OPENID_PROVIDER_URL=https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/openwebui/.well-known/openid-configuration
        OAUTH_CLIENT_ID=openwebui
        OAUTH_CLIENT_SECRET=${config.sops.placeholder."homelab/kanidm/oidc/openwebui/client-secret"}
        OAUTH_SCOPES=openid email profile
        OPENID_REDIRECT_URI=https://${configVars.networking.subdomains.openwebui}.${configVars.domain}/oauth/oidc/callback
      ''
    else
      ''
        ENABLE_OAUTH_SIGNUP=true
        OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
        OAUTH_PROVIDER_NAME=Authentik
        OPENID_PROVIDER_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/${config.sops.placeholder."open-webui-slug"}/.well-known/openid-configuration
        OAUTH_CLIENT_ID=${config.sops.placeholder."open-webui-clientid"}
        OAUTH_CLIENT_SECRET=${config.sops.placeholder."open-webui-clientsecret"}
        OAUTH_SCOPES=openid email profile
        OPENID_REDIRECT_URI=https://${configVars.networking.subdomains.openwebui}.${configVars.domain}/oauth/oidc/callback
      '';
  services.open-webui.environmentFile = lib.mkDefault config.sops.templates."open-webui.conf".path;
}
