{
  lib,
  configVars,
  config,
  ...
}:
let
  ssoProvider = config.services.ssoProvider.budget or "authentik";
  useKanidm = ssoProvider == "kanidm-oidc";
  discoveryURL =
    if useKanidm then
      "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/actual/"
    else
      "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/actual/";
in
{
  services.actual.enable = lib.mkDefault true;
  services.actual.openFirewall = lib.mkDefault true;
  services.actual.settings = lib.mkDefault {
    port = configVars.networking.ports.tcp.budget;
    openId = {
      discoveryURL = discoveryURL;
      server_hostname = "https://${configVars.networking.subdomains.budget}.${configVars.homeDomain}";
    };
  };

  # Authentik OIDC secrets
  sops.secrets."homelab/oidc/actual/authentik/client-id" = { };
  sops.secrets."homelab/oidc/actual/authentik/client-secret" = { };

  # Kanidm OIDC secrets
  sops.secrets."homelab/kanidm/oidc/actual/client-secret" = { };
  users.users."actual" = {
    isSystemUser = true;
    group = "actual";
  };
  users.groups."actual" = { };
  sops.templates."actual-oidc-keys.env" = {
    content =
      ''
        ACTUAL_OPENID_DISCOVERY_URL=${discoveryURL}
        ACTUAL_OPENID_SERVER_HOSTNAME=https://${configVars.networking.subdomains.budget}.${configVars.homeDomain}
      ''
      + (
        if useKanidm then
          ''
            ACTUAL_OPENID_CLIENT_ID=actual
            ACTUAL_OPENID_CLIENT_SECRET=${config.sops.placeholder."homelab/kanidm/oidc/actual/client-secret"}
          ''
        else
          ''
            ACTUAL_OPENID_CLIENT_ID=${config.sops.placeholder."homelab/oidc/actual/authentik/client-id"}
            ACTUAL_OPENID_CLIENT_SECRET=${config.sops.placeholder."homelab/oidc/actual/authentik/client-secret"}
          ''
      );
    owner = config.systemd.services.actual.serviceConfig.User;
  };
  systemd.services.actual.serviceConfig.EnvironmentFile =
    config.sops.templates."actual-oidc-keys.env".path;
}
