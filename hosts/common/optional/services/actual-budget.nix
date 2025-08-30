{
  lib,
  configVars,
  config,
  ...
}:
{
  services.actual.enable = lib.mkDefault true;
  services.actual.openFirewall = lib.mkDefault true;
  services.actual.settings = lib.mkDefault {
    port = configVars.networking.ports.tcp.budget;
    openId = {
      discoveryURL = "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/actual/";
      server_hostname = "https://${configVars.networking.subdomains.budget}.${configVars.homeDomain}";
    };
  };
  sops.secrets."homelab/oidc/actual/authentik/client-id" = { };
  sops.secrets."homelab/oidc/actual/authentik/client-secret" = { };
  users.users."actual" = {
    isSystemUser = true;
    group = "actual";
  };
  users.groups."actual" = { };
  sops.templates."actual-oidc-keys.env" = {
    content = ''
      ACTUAL_OPENID_DISCOVERY_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/actual/
      ACTUAL_OPENID_SERVER_HOSTNAME=https://${configVars.networking.subdomains.budget}.${configVars.homeDomain}
      ACTUAL_OPENID_CLIENT_ID=${config.sops.placeholder."homelab/oidc/actual/authentik/client-id"}
      ACTUAL_OPENID_CLIENT_SECRET=${config.sops.placeholder."homelab/oidc/actual/authentik/client-secret"}
    '';
    owner = config.systemd.services.actual.serviceConfig.User;
  };
  systemd.services.actual.serviceConfig.EnvironmentFile =
    config.sops.templates."actual-oidc-keys.env".path;
}
