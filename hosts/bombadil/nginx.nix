{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
{
  # Note that the NGINX setups for Mastodon is actually located in the Mastodon service file!

  # Set up sops secret for basic auth file
  services.nginx.enable = lib.mkDefault true;
  services.nginx.package = pkgs.nginxQuic.override { withSlice = true; };
  services.nginx.enableQuicBPF = true;
  services.nginx.recommendedOptimisation = true;
  services.nginx.recommendedTlsSettings = true;
  services.nginx.recommendedBrotliSettings = true;
  services.nginx.recommendedGzipSettings = true;
  services.nginx.recommendedZstdSettings = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";
  services.nginx.commonHttpConfig = ''
    # limit clients doing too many requests
    # can be tested with ab -n 20 -c 10 <host>
    limit_req_zone $binary_remote_addr zone=req_limit_per_ip:10m rate=25r/s;

    # limit clients opening too many connections
    limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
  '';
  services.nginx.virtualHosts.localhost.forceSSL = false;
  # services.nginx.virtualHosts.localhost.http2 = true;
  services.nginx.virtualHosts.localhost.listenAddresses = [
    "127.0.0.1"
    "[::1]"
  ];

  # UptimeKuma
  services.nginx.virtualHosts."${configVars.networking.subdomains.status}.${configVars.homeDomain}" = lib.mkIf config.services.uptime-kuma.enable {
    enableACME = true;
    http2 = true;
    forceSSL = true;
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString configVars.networking.ports.tcp.uptime-kuma}";
        proxyWebsockets = true;
      };
    };
  };

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "webmaster@${configVars.domain}";
}
