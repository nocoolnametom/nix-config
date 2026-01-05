{
  pkgs,
  lib,
  configVars,
  config,
  ...
}:
{
  services.kavita.enable = lib.mkDefault true;
  services.kavita.package = lib.mkDefault pkgs.unstable.kavita;
  services.kavita.settings.BaseUrl = lib.mkDefault null;
  services.kavita.settings.Cache = lib.mkDefault 75;
  services.kavita.settings.AllowIFraming = lib.mkDefault false;
  services.kavita.settings.Port = lib.mkDefault configVars.networking.ports.tcp.kavita;
  services.kavita.settings.HostName = lib.mkDefault "https:/${configVars.networking.subdomains.kavita}.${configVars.homeDomain}/";
  services.kavita.settings.OpenIdConnectSettings.Authority =
    lib.mkDefault "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/kavita/";
  services.kavita.settings.OpenIdConnectSettings.CustomScopes = lib.mkDefault [ ];
  services.kavita.settings.OpenIdConnectSettings.Enabled = lib.mkDefault true;
  # @TODO Once the service has been updated with better OIDC control we should address this
  services.kavita.settings.OpenIdConnectSettings.ClientId =
    lib.mkDefault configVars.networking.oidc.kavita.ClientId;
  services.kavita.settings.OpenIdConnectSettings.Secret =
    lib.mkDefault configVars.networking.oidc.kavita.Secret;
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
  services.kavitan.settings.OpenIdConnectSettings.Authority =
    lib.mkDefault "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/kavitan/";
  services.kavitan.settings.OpenIdConnectSettings.CustomScopes = lib.mkDefault [ ];
  services.kavitan.settings.OpenIdConnectSettings.Enabled = lib.mkDefault true;
  # @TODO Once the service has been updated with better OIDC control we should address this
  services.kavitan.settings.OpenIdConnectSettings.ClientId =
    lib.mkDefault configVars.networking.oidc.kavitan.ClientId;
  services.kavitan.settings.OpenIdConnectSettings.Secret =
    lib.mkDefault configVars.networking.oidc.kavitan.Secret;
  services.kavitan.tokenKeyFile = lib.mkDefault config.sops.secrets."kavitan-token".path;
  sops.secrets."kavitan-token".owner =
    if config.services.kavitan.enable then
      config.systemd.services.kavitan.serviceConfig.User
    else
      "root";
  users.users.kavitan.extraGroups = [ config.users.groups.datadat.name ];
}
