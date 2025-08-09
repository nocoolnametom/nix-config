{ lib, configVars, ... }:
{
  services.kavita.enable = lib.mkDefault true;
  services.kavita.settings.Port = configVars.networking.ports.tcp.kavita;
  services.kavita.tokenKeyFile = lib.mkDefault config.sops.secrets."kavita-token".path;
  sops.secrets."kavita-token".owner = config.systemd.services.kavita.serviceConfig.User;
}
