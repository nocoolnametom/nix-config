{
  lib,
  configVars,
  config,
  ...
}:
{
  services.hedgedoc.enable = lib.mkDefault true;
  services.hedgedoc.settings.domain = "${configVars.networking.subdomains.hedgedoc}.${configVars.homeDomain}";
  services.hedgedoc.settings.port = configVars.networking.ports.tcp.hedgedoc;
  networking.firewall.allowedTCPPorts = [ 8001 ];
  services.hedgedoc.settings.oauth.providerName = "authentik";
  services.hedgedoc.settings.oauth.scope = "openid email profile";
  services.hedgedoc.settings.oauth.baseURL =
    "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/hedgedoc/";
  services.hedgedoc.settings.oauth.userProfileURL =
    "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/userinfo/";
  services.hedgedoc.settings.oauth.tokenURL =
    "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/token/";
  services.hedgedoc.settings.oauth.authorizationURL =
    "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/authorize/";
  services.hedgedoc.settings.oauth.userProfileUsernameAttr = "preferred_username";
  services.hedgedoc.settings.oauth.userProfileDisplayNameAttr = "name";
  services.hedgedoc.settings.oauth.userProfileEmailAttr = "email";
  sops.secrets."homelab/oidc/hedgedoc/authentik/client-id" = { };
  sops.secrets."homelab/oidc/hedgedoc/authentik/client-secret" = { };
  sops.templates."hedgedoc-secrets.env" = {
    # If using postgres put the password in here
    content = ''
      CMD_OAUTH2_BASE_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/hedgedoc/
      CMD_OAUTH2_USER_PROFILE_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/userinfo/
      CMD_OAUTH2_TOKEN_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/token/
      CMD_OAUTH2_AUTHORIZATION_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/authorize/
      CMD_OAUTH2_PROVIDERNAME=Authentik
      CMD_OAUTH2_SCOPE=openid email profile
      CMD_OAUTH2_USER_PROFILE_USERNAME_ATTR=preferred_username
      CMD_OAUTH2_USER_PROFILE_DISPLAY_NAME_ATTR=name
      CMD_OAUTH2_USER_PROFILE_EMAIL_ATTR=email
      CMD_OAUTH2_CLIENT_ID=${config.sops.placeholder."homelab/oidc/hedgedoc/authentik/client-id"}
      CMD_OAUTH2_CLIENT_SECRET=${config.sops.placeholder."homelab/oidc/hedgedoc/authentik/client-secret"}
    '';
    owner = config.systemd.services.actual.serviceConfig.User;
  };
  services.hedgedoc.environmentFile = config.sops.templates."hedgedoc-secrets.env".path;
}
