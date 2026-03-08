{
  lib,
  config,
  configVars,
  ...
}:
{
  # nginx must be in the acme group to serve ACME http-01 challenge files.
  # The webroot /var/lib/acme/acme-challenge/ is owned acme:acme (750), so nginx
  # needs acme group membership to traverse it and read challenge tokens.
  users.users.nginx.extraGroups = [ "acme" ];
  # Ensure that the acme user has permissions to write new certificate in the nginx group
  users.users.acme.extraGroups = [ "nginx" ];
  systemd.tmpfiles.rules = [
    "d /var/lib/acme 2750 acme nginx -"
    "d /run/nginx 0755 root root -"
  ];

  # Note that the NGINX setups for Mastodon is actually located in the Mastodon service file!

  # Set up sops secret for basic auth file
  services.nginx.enable = lib.mkDefault true;
  services.nginx.enableQuicBPF = true;
  services.nginx.recommendedOptimisation = true;
  services.nginx.recommendedTlsSettings = true;
  services.nginx.recommendedBrotliSettings = true;
  services.nginx.recommendedGzipSettings = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";
  services.nginx.serverNamesHashBucketSize = 128;
  services.nginx.serverNamesHashMaxSize = 1024;
  # Listen on internal ports - HAProxy will forward to these
  services.nginx.defaultHTTPListenPort = 8080;
  services.nginx.defaultSSLListenPort = 8443;
  services.nginx.commonHttpConfig = ''
    # limit clients doing too many requests
    # can be tested with ab -n 20 -c 10 <host>
    limit_req_zone $binary_remote_addr zone=req_limit_per_ip:10m rate=25r/s;

    # limit clients opening too many connections
    limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;
  '';
  services.nginx.virtualHosts.localhost.forceSSL = false;
  # services.nginx.virtualHosts.localhost.http2 = true;
  # NOTE: Do NOT set listenAddresses on localhost. If localhost binds explicitly to
  # 127.0.0.1:8080, it creates a separate socket that captures ALL connections from
  # HAProxy (which forwards to 127.0.0.1:8080), causing every domain's HTTP requests
  # to be served by this vhost instead of their own. Without listenAddresses, all
  # vhosts share the 0.0.0.0:8080 socket and nginx uses server_name to route correctly.

  # Default catch-all: present main domain cert, drop unknown connections
  # Listens on internal ports (HAProxy forwards to these)
  services.nginx.virtualHosts."_default" = {
    default = true;
    listen = [
      {
        addr = "0.0.0.0";
        port = 8443;
        ssl = true;
      }
      {
        addr = "0.0.0.0";
        port = 8080;
      }
    ];
    forceSSL = true;
    sslCertificate = "/var/lib/acme/${configVars.domain}/fullchain.pem";
    sslCertificateKey = "/var/lib/acme/${configVars.domain}/key.pem";
    locations."/".return = "444";
  };

  # Make nginx tolerate startup failures (e.g., certs not yet issued on first boot)
  systemd.services.nginx = {
    serviceConfig = {
      Restart = lib.mkForce "on-failure";
      RestartSec = "10s";
    };
    unitConfig.FailureAction = "none";
  };

  # Mormon Sites reverse proxies
  services.nginx.virtualHosts."${configVars.networking.hosting.canon.domain}" =
    lib.mkIf config.services.mormonsites.enable
      {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${builtins.toString config.services.mormonsites.instances.canon.port}";
          proxyWebsockets = true;
        };
      };
  services.nginx.virtualHosts."${configVars.networking.hosting.quotes.domain}" =
    lib.mkIf config.services.mormonsites.enable
      {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${builtins.toString config.services.mormonsites.instances.quotes.port}";
          proxyWebsockets = true;
        };
      };
  services.nginx.virtualHosts."${configVars.networking.hosting.jod.domain}" =
    lib.mkIf config.services.mormonsites.enable
      {
        enableACME = true;
        http2 = true;
        forceSSL = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${builtins.toString config.services.mormonsites.instances.jod.port}";
          proxyWebsockets = true;
        };
      };

  # UptimeKuma
  services.nginx.virtualHosts."${configVars.networking.subdomains.uptime-kuma}.${configVars.homeDomain}" =
    lib.mkIf config.services.uptime-kuma.enable {
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
