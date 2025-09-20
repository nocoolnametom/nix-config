{
  pkgs,
  lib,
  configVars,
  config,
  ...
}:
{
  services.kavita.enable = lib.mkDefault true;
  services.kavita.package = pkgs.unstable.kavita;
  services.kavita.settings.Port = configVars.networking.ports.tcp.kavita;
  services.kavita.tokenKeyFile = lib.mkDefault config.sops.secrets."kavita-token".path;
  sops.secrets."kavita-token".owner =
    if config.services.kavita.enable then config.systemd.services.kavita.serviceConfig.User else "root";

  services.kavitan.enable = lib.mkDefault true;
  services.kavitan.package = pkgs.unstable.kavita;
  services.kavitan.settings.Port = configVars.networking.ports.tcp.kavitan;
  services.kavitan.tokenKeyFile = lib.mkDefault config.sops.secrets."kavitan-token".path;
  sops.secrets."kavitan-token".owner =
    if config.services.kavitan.enable then
      config.systemd.services.kavitan.serviceConfig.User
    else
      "root";
  users.users.kavitan.extraGroups = [ config.users.groups.datadat.name ];
}
