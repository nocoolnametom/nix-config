{
  config,
  lib,
  pkgs,
  configVars,
  ...
}:

# HAProxy SNI-based router for bombadil
# Routes traffic based on SNI hostname without terminating TLS:
# - Friend domains → bombadil nginx (localhost:8080/8443)
# - Homelab domains → estel Caddy (10.100.0.2:80/443 via WireGuard)

let
  hostName = config.networking.hostName;
  isBombadil = hostName == configVars.networking.external.bombadil.name;
in
{
  config = lib.mkIf isBombadil {
    services.haproxy = {
      enable = true;
      config = ''
        global
          log /dev/log local0
          log /dev/log local1 notice
          maxconn 4096
          user haproxy
          group haproxy
          daemon

        defaults
          log     global
          mode    tcp
          option  tcplog
          option  dontlognull
          timeout connect 5000ms
          timeout client  50000ms
          timeout server  50000ms

        # Frontend for HTTP (port 80)
        frontend http_frontend
          bind *:80
          bind :::80 v4v6
          mode tcp
          tcp-request inspect-delay 5s
          tcp-request content accept if HTTP

          # Friend domains - stay on bombadil
          acl is_exmormon_social hdr_end(host) -i exmormon.social
          acl is_exploring_morm hdr_end(host) -i exploringmormonism.com
          acl is_morm_quotes hdr_end(host) -i mormonquotes.com
          acl is_morm_canon hdr_end(host) -i mormoncanon.com
          acl is_jod hdr_end(host) -i journalofdiscourses.com

          # Akkoma/Fediverse subdomains hosted on bombadil nginx (exact matches only)
          # All other *.nocoolnametom.com traffic (kavitan, stash, etc.) falls through to homelab
          acl is_nct_bare    hdr(host) -i ${configVars.domain}
          acl is_nct_www     hdr(host) -i www.${configVars.domain}
          acl is_nct_cache   hdr(host) -i cache.${configVars.domain}
          acl is_nct_media   hdr(host) -i media.${configVars.domain}
          acl is_nct_private hdr(host) -i private.${configVars.domain}
          acl is_nct_handle  hdr(host) -i ${configVars.handles.mastodon}.${configVars.domain}

          # Locally-hosted subdomains under homeDomain (exact match)
          acl is_fmd_home     hdr(host) -i ${configVars.networking.subdomains.fmd}.${configVars.homeDomain}
          acl is_devices_home hdr(host) -i devices.${configVars.homeDomain}
          acl is_ntfy_home    hdr(host) -i ${configVars.networking.subdomains.ntfy}.${configVars.homeDomain}

          # Route friend domains to local nginx
          use_backend bombadil_http if is_exmormon_social
          use_backend bombadil_http if is_exploring_morm
          use_backend bombadil_http if is_morm_quotes
          use_backend bombadil_http if is_morm_canon
          use_backend bombadil_http if is_jod
          use_backend bombadil_http if is_nct_bare
          use_backend bombadil_http if is_nct_www
          use_backend bombadil_http if is_nct_cache
          use_backend bombadil_http if is_nct_media
          use_backend bombadil_http if is_nct_private
          use_backend bombadil_http if is_nct_handle
          use_backend bombadil_http if is_fmd_home
          use_backend bombadil_http if is_devices_home
          use_backend bombadil_http if is_ntfy_home

          # All other traffic goes to homelab (estel)
          default_backend homelab_http

        # Frontend for HTTPS (port 443)
        frontend https_frontend
          bind *:443
          bind :::443 v4v6
          mode tcp
          tcp-request inspect-delay 5s
          tcp-request content accept if { req_ssl_hello_type 1 }

          # Friend domains - stay on bombadil (using SNI)
          acl is_exmormon_social req_ssl_sni -m end exmormon.social
          acl is_exploring_morm req_ssl_sni -m end exploringmormonism.com
          acl is_morm_quotes req_ssl_sni -m end mormonquotes.com
          acl is_morm_canon req_ssl_sni -m end mormoncanon.com
          acl is_jod req_ssl_sni -m end journalofdiscourses.com

          # Akkoma/Fediverse subdomains hosted on bombadil nginx (exact matches only)
          # All other *.nocoolnametom.com traffic (kavitan, stash, etc.) falls through to homelab
          acl is_nct_bare    req_ssl_sni -i ${configVars.domain}
          acl is_nct_www     req_ssl_sni -i www.${configVars.domain}
          acl is_nct_cache   req_ssl_sni -i cache.${configVars.domain}
          acl is_nct_media   req_ssl_sni -i media.${configVars.domain}
          acl is_nct_private req_ssl_sni -i private.${configVars.domain}
          acl is_nct_handle  req_ssl_sni -i ${configVars.handles.mastodon}.${configVars.domain}

          # Locally-hosted subdomains under homeDomain (exact match)
          acl is_fmd_home     req_ssl_sni -i ${configVars.networking.subdomains.fmd}.${configVars.homeDomain}
          acl is_devices_home req_ssl_sni -i devices.${configVars.homeDomain}
          acl is_ntfy_home    req_ssl_sni -i ${configVars.networking.subdomains.ntfy}.${configVars.homeDomain}

          # Route friend domains to local nginx
          use_backend bombadil_https if is_exmormon_social
          use_backend bombadil_https if is_exploring_morm
          use_backend bombadil_https if is_morm_quotes
          use_backend bombadil_https if is_morm_canon
          use_backend bombadil_https if is_jod
          use_backend bombadil_https if is_nct_bare
          use_backend bombadil_https if is_nct_www
          use_backend bombadil_https if is_nct_cache
          use_backend bombadil_https if is_nct_media
          use_backend bombadil_https if is_nct_private
          use_backend bombadil_https if is_nct_handle
          use_backend bombadil_https if is_fmd_home
          use_backend bombadil_https if is_devices_home
          use_backend bombadil_https if is_ntfy_home

          # All other traffic goes to homelab (estel)
          default_backend homelab_https

        # Backend: Bombadil nginx (friend domains)
        backend bombadil_http
          mode tcp
          server bombadil_nginx 127.0.0.1:8080 check

        backend bombadil_https
          mode tcp
          server bombadil_nginx 127.0.0.1:8443 check

        # Backend: Homelab via WireGuard (estel Caddy)
        backend homelab_http
          mode tcp
          server estel_caddy ${configVars.networking.wireguard.estel.ip}:80 check

        backend homelab_https
          mode tcp
          server estel_caddy ${configVars.networking.wireguard.estel.ip}:443 check
      '';
    };

    # Ensure haproxy user/group exists
    users.users.haproxy = {
      isSystemUser = true;
      group = "haproxy";
    };
    users.groups.haproxy = { };

    # HAProxy depends on WireGuard being up
    systemd.services.haproxy = {
      after = [ "wireguard-wg-homelab.service" ];
      wants = [ "wireguard-wg-homelab.service" ];
    };
  };
}
