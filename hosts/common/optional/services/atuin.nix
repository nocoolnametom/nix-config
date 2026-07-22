{
  lib,
  configVars,
  ...
}:
{
  services.atuin = {
    enable = lib.mkDefault true;
    host = "127.0.0.1";
    port = configVars.networking.ports.tcp."atuin-sync";
    openRegistration = false;
    database.createLocally = true;
  };
}
