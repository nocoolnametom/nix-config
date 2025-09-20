{
  pkgs,
  lib,
  configVars,
  config,
  ...
}:
{
  services.postgresql.enable = lib.mkDefault true;
  services.postgresql.ensureDatabases = [ "hedgedoc" ];
  services.postgresql.ensureUsers = [ { name = "hedgedoc"; ensureDBOwnership = true; } ];
  services.hedgedoc.enable = lib.mkDefault true;
  services.hedgedoc.settings.db.username = "hedgedoc";
  services.hedgedoc.settings.db.database = "hedgedoc";
  services.hedgedoc.settings.db.host = "/run/postgresql";
  services.hedgedoc.settings.db.dialect = "postgresql";
  services.hedgedoc.settings.domain = lib.mkDefault "${configVars.networking.subdomains.hedgedoc}.${configVars.homeDomain}";
  services.hedgedoc.settings.host = lib.mkDefault "0.0.0.0";
  services.hedgedoc.settings.port = lib.mkDefault configVars.networking.ports.tcp.hedgedoc;
  services.hedgedoc.settings.protocolUseSSL = lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [ 8001 ];
  services.hedgedoc.settings.email = true;
  #services.hedgedoc.settings.allowEmailRegister = false;
  services.hedgedoc.settings.allowAnonymous = false;
  services.hedgedoc.settings.requireFreeURLAuthentication = true;
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
      CMD_OAUTH2_PROVIDERNAME=authentik
      CMD_OAUTH2_CLIENT_ID=${config.sops.placeholder."homelab/oidc/hedgedoc/authentik/client-id"}
      CMD_OAUTH2_CLIENT_SECRET=${config.sops.placeholder."homelab/oidc/hedgedoc/authentik/client-secret"}
      CMD_OAUTH2_SCOPE="openid email profile"
      CMD_OAUTH2_USER_PROFILE_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/userinfo/
      CMD_OAUTH2_TOKEN_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/token/
      CMD_OAUTH2_AUTHORIZATION_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/authorize/
      CMD_OAUTH2_USER_PROFILE_USERNAME_ATTR=preferred_username
      CMD_OAUTH2_USER_PROFILE_DISPLAY_NAME_ATTR=name
      CMD_OAUTH2_USER_PROFILE_EMAIL_ATTR=email
    '';
    owner = config.systemd.services.actual.serviceConfig.User;
  };
  services.hedgedoc.environmentFile = config.sops.templates."hedgedoc-secrets.env".path;
}
