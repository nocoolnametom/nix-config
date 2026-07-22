{
  lib,
  configVars,
  ...
}:
{
  services.atuin.enable = lib.mkDefault true;
  services.atuin.host = lib.mkDefault "0.0.0.0";
  services.atuin.port = lib.mkDefault configVars.networking.ports.tcp."atuin-sync";
  services.atuin.openRegistration = lib.mkDefault false;
  services.atuin.database.createLocally = lib.mkDefault true;
}
