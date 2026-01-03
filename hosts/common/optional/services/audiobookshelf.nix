{
  lib,
  configVars,
  config,
  pkgs,
  ...
}:
{
  services.audiobookshelf.enable = lib.mkDefault true;
  services.audiobookshelf.host = lib.mkDefault "0.0.0.0";
  services.audiobookshelf.port = lib.mkDefault configVars.networking.ports.tcp.audiobookshelf;
  services.audiobookshelf.openFirewall = lib.mkDefault true;
  users.users.audiobookshelf.extraGroups = [ config.users.groups.datadat.name ];
}
