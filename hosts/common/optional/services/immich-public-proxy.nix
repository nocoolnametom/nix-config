{ lib, configVars, ... }:
{
  services.immich-public-proxy.enable = lib.mkDefault true;
  services.immich-public-proxy.immichUrl = "http://${configVars.networking.subnets.cirdan.ip}:${builtins.toString configVars.networking.ports.tcp.immich}";
  services.immich-public-proxy.port = configVars.networking.ports.tcp.immich-share;
  services.immich-public-proxy.openFirewall = lib.mkDefault true;
}
