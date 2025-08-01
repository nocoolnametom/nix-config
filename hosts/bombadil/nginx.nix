{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
{
  # We're using bombadil for failover-redirects for the Uptime-Kuma status page
  services.failoverRedirects.enable = lib.mkDefault true;
  services.failoverRedirects.excludeDomains =
    let
      akkomaUrl = config.services.akkoma.config.":pleroma"."Pleroma.Web.Endpoint".url.host;
      akkomaUrls = lib.optionals config.services.akkoma.enable [
        akkomaDomain
        "www.${akkomaDomain}"
        "${configVars.handles.mastodon}.${akkomaDomain}"
        "private.${akkomaDomain}"
        "cache.${akkomaDomain}"
        "media.${akkomaDomain}"
      ];
      goToSocialUrls = lib.optionals config.services.gotosocial.enable [
        config.services.gotosocial.settings.host
      ];
      mastodonUrls = lib.optionals config.services.mastodon.enable [
        config.services.mastodon.localDomain
        "reddit-feed.${config.services.mastodon.localDomain}"
        "www.${config.services.mastodon.localDomain}"
      ];
      wordpressUrls =
        (builtins.attrNames services.wordpress.sites)
        ++ (builtins.map (x: "www.${x}") (builtins.attrNames services.wordpress.sites))
        ++ (builtins.map (x: "beta.${x}") (builtins.attrNames services.wordpress.sites));
    in
    [
      # Specify any manual urls here not made in the above dynamic lists
    ]
    ++ [ config.services.failoverRedirects.statusPageDomain ]
    ++ akkomaUrls
    ++ goToSocialUrls
    ++ mastodonUrls
    ++ wordpressUrls;
  services.failoverRedirects.statusPageDomain = "${configVars.networking.subdomains.uptime-kuma}.${configVars.homeDomain}";
  # Ensure that the acme user has permissions to write new certificate in the nginx group
  users.users.acme.extraGroups = [ "nginx" ];
  users.users.acme.openssh.authorizedKeys.keyFiles = [
    ./acme-failover-key.pub
  ];
  systemd.tmpfiles.rules = [
    "d /var/lib/acme 2750 acme nginx -"
  ];

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
