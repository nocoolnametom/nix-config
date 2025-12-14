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
      akkomaDomain = config.services.akkoma.config.":pleroma"."Pleroma.Web.Endpoint".url.host;
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
        (builtins.attrNames config.services.wordpress.sites)
        ++ (builtins.map (x: "www.${x}") (builtins.attrNames config.services.wordpress.sites))
        ++ (builtins.map (x: "beta.${x}") (builtins.attrNames config.services.wordpress.sites));
    in
    [
      # Specify any manual urls here not made in the above dynamic lists
      config.networking.hosting.canon.domain
      config.networking.hosting.quotes.domain
      config.networking.hosting.jod.domain
    ]
    ++ [ config.services.failoverRedirects.statusPageDomain ]
    ++ akkomaUrls
    ++ goToSocialUrls
    ++ mastodonUrls
    ++ wordpressUrls;
  services.failoverRedirects.statusPageDomain = "${configVars.networking.subdomains.uptime-kuma}.${configVars.homeDomain}";
  # Ensure that the acme user has permissions to write new certificate in the nginx group
  users.users.acme.extraGroups = [ "nginx" ];
  users.users.acme.shell = pkgs.bash;
  services.openssh.settings.AllowUsers = [ "acme" ];
  # wheel is included here because otherwise it wipes it out, not sure why
  services.openssh.settings.AllowGroups = [
    "acme"
    "wheel"
  ];
  users.users.acme.openssh.authorizedKeys.keyFiles = [
    ./acme-failover-key.pub
  ];
  systemd.tmpfiles.rules = [
    "d /var/lib/acme 2750 acme nginx -"
  ];

  # Rsync certificate receiver - fixes permissions after certs are synced from estel
  services.rsyncCertSync.receiver.enable = true;
  services.rsyncCertSync.receiver.certPath = "/var/lib/acme";
  services.rsyncCertSync.receiver.certUser = "acme";
  services.rsyncCertSync.receiver.certGroup = "nginx";
  services.rsyncCertSync.receiver.timerSchedule = "*-*-* 03:00:00"; # Match estel's sender schedule
  services.rsyncCertSync.receiver.delayMinutes = 5; # Run 5 minutes after rsync completes

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

  # Mormon Sites reverse proxies
  services.nginx.virtualHosts."${config.networking.hosting.canon.domain}" = lib.mkIf config.services.mormonsites.enable {
    enableACME = true;
    http2 = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.mormonsites.instances.canon.port}";
      proxyWebsockets = true;
    };
  };
  services.nginx.virtualHosts."${config.networking.hosting.quotes.domain}" = lib.mkIf config.services.mormonsites.enable {
    enableACME = true;
    http2 = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.mormonsites.instances.quotes.port}";
      proxyWebsockets = true;
    };
  };
  services.nginx.virtualHosts."${config.networking.hosting.jod.domain}" = lib.mkIf config.services.mormonsites.enable {
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
