{ lib, configVars, config, ... }:
{
  services.kavita.enable = lib.mkDefault true;
  services.kavita.settings.Port = configVars.networking.ports.tcp.kavitan;
  services.kavita.tokenKeyFile = lib.mkDefault config.sops.secrets."kavitan-token".path;
  sops.secrets."kavitan-token".owner = config.systemd.services.kavita.serviceConfig.User;
  users.users.kavita.extraGroups = [ config.users.groups.datadat.name ];
}
