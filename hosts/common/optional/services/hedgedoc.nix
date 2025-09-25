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
  services.postgresql.ensureUsers = [
    {
      name = "hedgedoc";
      ensureDBOwnership = true;
    }
  ];
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
  services.hedgedoc.settings.email = false;
  services.hedgedoc.settings.allowEmailRegister = false;
  services.hedgedoc.settings.requireFreeURLAuthentication = true;
  services.hedgedoc.settings.oauth2.providername = "authentik";
  services.hedgedoc.settings.oauth2.scope = "openid email profile";
  services.hedgedoc.settings.oauth2.baseURL =
    "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/hedgedoc/";
  services.hedgedoc.settings.oauth2.userProfileURL =
    "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/userinfo/";
  services.hedgedoc.settings.oauth2.tokenURL =
    "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/token/";
  services.hedgedoc.settings.oauth2.authorizationURL =
    "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/authorize/";
  services.hedgedoc.settings.oauth2.userProfileUsernameAttr = "preferred_username";
  services.hedgedoc.settings.oauth2.userProfileDisplayNameAttr = "name";
  services.hedgedoc.settings.oauth2.userProfileEmailAttr = "email";
  sops.secrets."homelab/oidc/hedgedoc/authentik/client-id" = { };
  sops.secrets."homelab/oidc/hedgedoc/authentik/client-secret" = { };
  sops.secrets."homelab/sessions/hedgedoc/session-secret" = { };
  sops.templates."hedgedoc-secrets.env" = {
    content = ''
      CMD_SESSION_SECRET=${config.sops.placeholder."homelab/sessions/hedgedoc/session-secret"}
      CMD_OAUTH2_CLIENT_ID=${config.sops.placeholder."homelab/oidc/hedgedoc/authentik/client-id"}
      CMD_OAUTH2_CLIENT_SECRET=${config.sops.placeholder."homelab/oidc/hedgedoc/authentik/client-secret"}
    '';
    owner = config.systemd.services.hedgedoc.serviceConfig.User;
  };
  services.hedgedoc.environmentFile = config.sops.templates."hedgedoc-secrets.env".path;
}
