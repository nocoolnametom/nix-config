{ lib, configVars, ... }:
{
  services.audiobookshelf.enable = lib.mkDefault true;
  services.audiobookshelf.host = lib.mkDefault "0.0.0.0";
  services.audiobookshelf.port = lib.mkDefault configVars.networking.ports.tcp.audiobookshelf;
  services.audiobookshelf.openFirewall = lib.mkDefault true;
}
