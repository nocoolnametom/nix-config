{
  lib,
  configVars,
  ...
}:
{
  services.immich.enable = lib.mkDefault true;
  services.immich.openFirewall = lib.mkDefault true;
  services.immich.port = configVars.networking.ports.tcp.immich;
  services.immich.accelerationDevices = lib.mkDefault null;
}
