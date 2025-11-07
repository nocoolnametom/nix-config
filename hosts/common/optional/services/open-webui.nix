{ lib, pkgs, configVars, ... }: {
  services.open-webui.enable = lib.mkDefault true;
  services.open-webui.host = lib.mkDefault "0.0.0.0";
  services.open-webui.port = lib.mkDefault configVars.networking.ports.tcp.openwebui;
  services.open-webui.openFirewall = lib.mkDefault true;

  sops.secrets = {
    "open-webui-slug" = { };
    "open-webui-clientid" = { };
    "open-webui-clientsecret" = { };
  };
  sops.templates."open-webui.conf".content = ''
    ENABLE_OAUTH_SIGNUP=true
    OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
    OAUTH_PROVIDER_NAME=Authentik
    OPENID_PROVIDER_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/${
      config.sops.placeholder."open-webui-slug"
    }/.well-known/openid-configuration
    OAUTH_CLIENT_ID=${config.sops.placeholder."open-webui-clientid"}
    OAUTH_CLIENT_SECRET=${config.sops.placeholder."open-webui-clientsecret"}
    OAUTH_SCOPES=openid email profile
    OPENID_REDIRECT_URI=https://${configVars.networking.subdomains.openwebui}.${configVars.domain}/oauth/oidc/callback
  '';
  services.open-webui.environmentFile = lib.mkDefault config.sops.templates."open-webui.conf".path;
}