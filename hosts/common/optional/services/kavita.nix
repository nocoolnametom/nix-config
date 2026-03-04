{
  pkgs,
  lib,
  configVars,
  config,
  ...
}:
let
  kavitaSsoProvider = config.services.ssoProvider.kavita or "authentik";
  kavitanSsoProvider = config.services.ssoProvider.kavitan or "authentik";
  kavitaUseKanidm = kavitaSsoProvider == "kanidm-oidc";
  kavitanUseKanidm = kavitanSsoProvider == "kanidm-oidc";
in
{
  # TODO: Kavita stores OIDC secrets in configVars instead of sops.
  # For Kanidm integration, we should migrate to sops secrets like other services.
  # Add sops secrets for Kanidm OIDC once ready to migrate:
  # sops.secrets."homelab/kanidm/oidc/kavita/client-secret" = { };
  # sops.secrets."homelab/kanidm/oidc/kavitan/client-secret" = { };
  services.kavita.enable = lib.mkDefault true;
  services.kavita.package = lib.mkDefault pkgs.unstable.kavita;
  services.kavita.settings.BaseUrl = lib.mkDefault null;
  services.kavita.settings.Cache = lib.mkDefault 75;
  services.kavita.settings.AllowIFraming = lib.mkDefault false;
  services.kavita.settings.Port = lib.mkDefault configVars.networking.ports.tcp.kavita;
  services.kavita.settings.HostName = lib.mkDefault "https:/${configVars.networking.subdomains.kavita}.${configVars.homeDomain}/";
  services.kavita.settings.OpenIdConnectSettings = {
    Authority = lib.mkDefault (
      if kavitaUseKanidm then
        "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/kavita/"
      else
        "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/kavita/"
    );
    CustomScopes = lib.mkDefault [ ];
    Enabled = lib.mkDefault true;
    # TODO: For Kanidm, migrate to sops secrets instead of configVars
    ClientId = lib.mkDefault (
      if kavitaUseKanidm then "kavita" else configVars.networking.oidc.kavita.ClientId
    );
    Secret = lib.mkDefault (
      if kavitaUseKanidm then
        configVars.networking.oidc.kavita.Secret # TODO: Replace with sops secret
      else
        configVars.networking.oidc.kavita.Secret
    );
  };
  services.kavita.tokenKeyFile = lib.mkDefault config.sops.secrets."kavita-token".path;
  sops.secrets."kavita-token".owner =
    if config.services.kavita.enable then config.systemd.services.kavita.serviceConfig.User else "root";

  services.kavitan.enable = lib.mkDefault true;
  services.kavitan.package = lib.mkDefault pkgs.unstable.kavita;
  services.kavitan.settings.BaseUrl = lib.mkDefault null;
  services.kavitan.settings.Cache = lib.mkDefault 75;
  services.kavitan.settings.AllowIFraming = lib.mkDefault false;
  services.kavitan.settings.Port = lib.mkDefault configVars.networking.ports.tcp.kavitan;
  services.kavitan.settings.HostName = lib.mkDefault "https:/${configVars.networking.subdomains.kavitan}.${configVars.domain}/";
  services.kavitan.settings.OpenIdConnectSettings = {
    Authority = lib.mkDefault (
      if kavitanUseKanidm then
        "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/kavitan/"
      else
        "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/kavitan/"
    );
    CustomScopes = lib.mkDefault [ ];
    Enabled = lib.mkDefault true;
    # TODO: For Kanidm, migrate to sops secrets instead of configVars
    ClientId = lib.mkDefault (
      if kavitanUseKanidm then "kavitan" else configVars.networking.oidc.kavitan.ClientId
    );
    Secret = lib.mkDefault (
      if kavitanUseKanidm then
        configVars.networking.oidc.kavitan.Secret # TODO: Replace with sops secret
      else
        configVars.networking.oidc.kavitan.Secret
    );
  };
  services.kavitan.tokenKeyFile = lib.mkDefault config.sops.secrets."kavitan-token".path;
  sops.secrets."kavitan-token".owner =
    if config.services.kavitan.enable then
      config.systemd.services.kavitan.serviceConfig.User
    else
      "root";
  users.users.kavitan.extraGroups = [ config.users.groups.datadat.name ];
}
