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

  services.desktopManager.plasma6.enable = true;
  jovian.steam.desktopSession = "plasma";

  services.greetd.settings.default_session.command = lib.mkForce config.services.greetd.settings.initial_session.command;
  services.greetd.settings.initial_session.command =
    lib.mkForce "${pkgs.greetd.tuigreet}/bin/tuigreet --asterisks --remember --remember-session - --time";
}
