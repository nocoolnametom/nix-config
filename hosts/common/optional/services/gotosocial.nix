{
  config,
  configVars,
  lib,
  ...
}:
{
  services.gotosocial.enable = lib.mkDefault true;
  services.gotosocial.settings.host = lib.mkDefault "dev.${configVars.domain}";
  services.gotosocial.settings.account-domain = lib.mkDefault configVars.domain;
  services.gotosocial.settings.port = lib.mkDefault 8080;
  services.gotosocial.settings.protocol = lib.mkDefault "https";
  services.gotosocial.settings.bind-address = lib.mkDefault "127.0.0.1";
  services.gotosocial.settings.storage-local-base-path = lib.mkDefault "/var/lib/gotosocial/storage";
  systemd.tmpfiles.rules = [
    "d ${config.services.gotosocial.settings.storage-local-base-path} 755 gotosocial gotosocial"
  ];
  services.gotosocial.settings.instance-federation-spam-filter = lib.mkDefault true;
  services.gotosocial.settings.instance-inject-mastodon-version = lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  services.nginx.clientMaxBodySize = lib.mkDefault "40M";
  services.nginx.virtualHosts."${config.services.gotosocial.settings.host}" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      recommendedProxySettings = true;
      proxyWebsockets = true;
      proxyPass = "http://${config.services.gotosocial.settings.bind-address}:${toString config.services.gotosocial.settings.port}";
    };
  };
}
