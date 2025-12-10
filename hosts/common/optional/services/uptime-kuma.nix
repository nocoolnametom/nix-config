{ lib, pkgs, configVars, ... }:
{
  services.uptime-kuma.enable = lib.mkDefault true;
  services.uptime-kuma.package = lib.mkDefault pkgs.unstale.uptime-kuma;
  services.uptime-kuma.settings.PORT = builtins.toString configVars.networking.ports.tcp.uptime-kuma;
  services.uptime-kuma.settings.UPTIME_KUMA_DB_TYPE = lib.mkDefault "sqlite";
}
