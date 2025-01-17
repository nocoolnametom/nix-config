{ configVars, lib, ... }:
{
  services.gotosocial.enable = lib.mkDefault true;
  services.gotosocial.settings.host = lib.mkDefault "dev.${configVars.domain}";
  services.gotosocial.settings.port = lib.mkDefault 8080;
  services.gotosocial.settings.protocol = lib.mkDefault "https";
  services.gotosocial.settings.bind-address = lib.mkDefault "127.0.0.1";
  services.gotosocial.settings.instance-federation-spam-filter = lib.mkDefault true;
  services.gotosocial.settings.instance-inject-mastodon-version = lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  services.nginx.enable = true;
  service.nginx.clientMaxBodySize = lib.mkDefault "40M";
  services.nginx.virtualHosts."dev.${configVars.domain}".enableACME = true;
  services.nginx.virtualHosts."dev.${configVars.domain}".forceSSL = true;
  services.nginx.virtualHosts."dev.${configVars.domain}".locations."/".recommendedProxySettings =
    true;
  services.nginx.virtualHosts."dev.${configVars.domain}".locations."/".proxyWebsockets = true;
  services.nginx.virtualHosts."dev.${configVars.domain}".locations."/".proxyPass =
    "http://${config.services.gotosocial.settings.bind-address}:${toString config.services.gotosocial.settings.port}";
}
