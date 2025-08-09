{ lib, configVars, ... }:
{
  services.uptime-kuma.enable = lib.mkDefault true;
  services.uptime-kuma.settings.PORT = builtins.toString configVars.networking.ports.tcp.uptime-kuma;
}
