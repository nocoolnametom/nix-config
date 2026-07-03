{
  lib,
  configVars,
  ...
}:
{
  services.fmd.enable = lib.mkDefault true;
  services.fmd.settings.PortInsecure = lib.mkDefault (
    builtins.toString configVars.networking.ports.tcp.fmd
  );
  services.fmd.settings.RemoteIpHeader = lib.mkDefault "X-Forwarded-For";
  services.fmd.openFirewall = lib.mkDefault true;
}
