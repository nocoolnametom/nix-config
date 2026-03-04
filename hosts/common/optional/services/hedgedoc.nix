{
  pkgs,
  lib,
  configVars,
  config,
  ...
}:
let
  ssoProvider = config.services.ssoProvider.hedgedoc or "authentik";
  useKanidm = ssoProvider == "kanidm-oidc";
  baseURL =
    if useKanidm then
      "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/hedgedoc/"
    else
      "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/hedgedoc/";
in
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
  services.hedgedoc.settings.oauth2 = {
    providername = if useKanidm then "Kanidm" else "authentik";
    scope = "openid email profile";
    baseURL = baseURL;
    userProfileURL =
      if useKanidm then
        "${baseURL}userinfo"
      else
        "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/userinfo/";
    tokenURL =
      if useKanidm then
        "${baseURL}token"
      else
        "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/token/";
    authorizationURL =
      if useKanidm then
        "${baseURL}authorize"
      else
        "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/authorize/";
    userProfileUsernameAttr = "preferred_username";
    userProfileDisplayNameAttr = "name";
    userProfileEmailAttr = "email";
  };

  # Authentik OIDC secrets
  sops.secrets."homelab/oidc/hedgedoc/authentik/client-id" = { };
  sops.secrets."homelab/oidc/hedgedoc/authentik/client-secret" = { };

  # Kanidm OIDC secrets
  sops.secrets."homelab/kanidm/oidc/hedgedoc/client-secret" = { };
  sops.secrets."homelab/sessions/hedgedoc/session-secret" = { };
  sops.templates."hedgedoc-secrets.env" = {
    content =
      ''
        CMD_SESSION_SECRET=${config.sops.placeholder."homelab/sessions/hedgedoc/session-secret"}
      ''
      + (
        if useKanidm then
          ''
            CMD_OAUTH2_CLIENT_ID=hedgedoc
            CMD_OAUTH2_CLIENT_SECRET=${config.sops.placeholder."homelab/kanidm/oidc/hedgedoc/client-secret"}
          ''
        else
          ''
            CMD_OAUTH2_CLIENT_ID=${config.sops.placeholder."homelab/oidc/hedgedoc/authentik/client-id"}
            CMD_OAUTH2_CLIENT_SECRET=${config.sops.placeholder."homelab/oidc/hedgedoc/authentik/client-secret"}
          ''
      );
    owner = config.systemd.services.hedgedoc.serviceConfig.User;
  };
  services.hedgedoc.environmentFile = config.sops.templates."hedgedoc-secrets.env".path;
}
