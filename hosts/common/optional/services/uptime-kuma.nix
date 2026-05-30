{
  lib,
  pkgs,
  configVars,
  ...
}:
{
  services.uptime-kuma.enable = lib.mkDefault true;
  services.uptime-kuma.package = lib.mkDefault pkgs.uptime-kuma;
  services.uptime-kuma.settings.PORT = toString configVars.networking.ports.tcp.uptime-kuma;
  services.uptime-kuma.settings.UPTIME_KUMA_DB_TYPE = lib.mkDefault "sqlite";
}
