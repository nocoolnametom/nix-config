{
  inputs,
  pkgs,
  lib,
  configVars,
  config,
  ...
}:
{
  imports = [
    inputs.jovian.nixosModules.default
  ];

  jovian.steam.enable = lib.mkDefault true;
  jovian.steam.autoStart = lib.mkDefault true;
  jovian.steam.user = lib.mkDefault configVars.username;

  autoLogin.enable = lib.mkDefault true;
  autoLogin.username = lib.mkDefault configVars.username;
}
