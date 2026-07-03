{
  lib,
  configVars,
  ...
}:
{
  services.ntfy-sh.enable = lib.mkDefault true;
  services.ntfy-sh.settings.listen-http = "127.0.0.1:${builtins.toString configVars.networking.ports.tcp.ntfy}";
  services.ntfy-sh.settings.base-url = "https://${configVars.networking.subdomains.ntfy}.${configVars.homeDomain}";
  services.ntfy-sh.settings.behind-proxy = true;
}
