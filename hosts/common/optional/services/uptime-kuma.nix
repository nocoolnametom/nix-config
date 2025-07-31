{ lib, configVars, ... }: {
  services.uptime-kuma.enable = lib.mkDefault true;
  services.uptime-kuma.settings.PORT = configVars.networking.ports.tcp.uptime-kuma;
}
