{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.failoverRedirects;
in
{
  options.services.failoverRedirects = {
    enable = lib.mkEnableOption "Failover Redirects Nginx Config Generator";

    excludeDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of domains to exclude (e.g., status.domain.name)";
    };

    statusPageDomain = lib.mkOption {
      type = lib.types.str;
      default = "status.domain.name";
      description = "Domain to redirect the failovers to with a temporary redirect";
    };

    outputConfigPath = lib.mkOption {
      type = lib.types.path;
      default = "/etc/nginx/failover-redirects.conf";
      description = "Path to write the generated Nginx failover redirects config";
    };

    certPath = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/acme";
      description = "Path to the directory containing SSL certificates for failover domains";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = "Port for failover HTTPS redirects (set to 8443 when using HAProxy)";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.nginx.reloadTriggers = [ cfg.outputConfigPath ];

    systemd.services.failover-redirects-generate = {
      description = "Generate Nginx Failover Redirects Config with one server block per domain";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScriptBin "failover-redirects-generate" ''
                    set -e
                    mkdir -p $(dirname ${cfg.outputConfigPath})

                    tmpfile=$(mktemp)
                    echo "# Generated failover redirect config - DO NOT EDIT" > $tmpfile
                    echo "" >> $tmpfile

                    # Iterate domains in certificate directory
                    for dir in ${cfg.certPath}/*; do
                      domain=$(basename "$dir")

                      # Skip excluded domains and acme-challenge
                      if [ "$domain" = "acme-challenge" ]; then continue; fi
                      skip=0
                      for exclude in ${lib.concatStringsSep " " cfg.excludeDomains}; do
                        if [ "$domain" = "$exclude" ]; then
                          skip=1
                          break
                        fi
                      done
                      if [ "$skip" -eq 1 ]; then continue; fi

                      # Check if cert files exist for safety
                      if [ ! -f "${cfg.certPath}/$domain/fullchain.pem" ] || [ ! -f "${cfg.certPath}/$domain/key.pem" ]; then
                        echo "Warning: cert files missing for $domain, skipping" >&2
                        continue
                      fi

                      # Output one server block per domain
                      cat >> $tmpfile <<EOF
          server {
              listen ${toString cfg.httpsPort} ssl;
              listen [::]:${toString cfg.httpsPort} ssl;
              server_name ${"$"}{domain};
              ssl_certificate ${cfg.certPath}/${"$"}{domain}/fullchain.pem;
              ssl_certificate_key ${cfg.certPath}/${"$"}{domain}/key.pem;

              location / {
                  return 302 https://${cfg.statusPageDomain}\$request_uri;
              }
          }
          EOF

                    done

                    mv $tmpfile ${cfg.outputConfigPath}
                    chmod 644 ${cfg.outputConfigPath}
        ''}/bin/failover-redirects-generate";
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.paths.failover-redirects-watch = {
      description = "Watch certificate directory for changes to regenerate failover config";
      pathConfig = {
        PathModified = cfg.certPath;
      };
      wantedBy = [ "multi-user.target" ];
      unitConfig = {
        Unit = "failover-redirects-generate.service";
      };
    };

    systemd.services.nginx-reload-on-failover-change = {
      description = "Reload Nginx when failover-redirects.conf changes";
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScriptBin "nginx-reload-on-failover-change" ''
          ${pkgs.inotify-tools}/bin/inotifywait -m -e modify ${cfg.outputConfigPath} | while read; do
            systemctl reload nginx
          done
        ''}/bin/nginx-reload-on-failover-change";
        Restart = "always";
        RestartSec = 2;
      };
      wantedBy = [ "multi-user.target" ];
    };

    # Ensure nginx is enabled
    services.nginx.enable = lib.mkDefault true;

    # Include the generated config file in nginx config
    services.nginx.appendHttpConfig = ''
      include ${cfg.outputConfigPath};
    '';

    environment.systemPackages = [
      # This script can be used to ensure that we're loading the proper SSL certs for the failover domains
      (pkgs.writeShellScriptBin "testing-failovers-root" ''
        HOSTNAME=${config.networking.hostName}

        for domain in $(ls ${cfg.certPath}); do
          if [[ "$domain" == "acme-challenge" ]]; then continue; fi;

          echo -n "Testing $domain (IPv4) ... "
          ${pkgs.openssl}/bin/openssl s_client -connect $HOSTNAME:${toString cfg.httpsPort} -servername "$domain" -4 < /dev/null 2>/dev/null \
            | ${pkgs.openssl}/bin/openssl x509 -noout -subject \
            | grep "CN=$domain" && echo "OK" || echo "FAIL";

          echo -n "Testing $domain (IPv6) ... "
          # Resolve IPv6 address from /etc/hosts or DNS
          IPV6_ADDR=$(ip -6 addr show dev eth0 | grep 'scope global' | grep -oP 'inet6 \K[^/]*f03c:95ff:fe43:[0-9a-fA-F:]+' | head -n1)

          if [[ -z "$IPV6_ADDR" ]]; then
            echo "SKIP (No IPv6 found)"
            continue
          fi

          ${pkgs.openssl}/bin/openssl s_client -connect "[$IPV6_ADDR]:${toString cfg.httpsPort}" -servername "$domain" < /dev/null 2>/dev/null \
            | ${pkgs.openssl}/bin/openssl x509 -noout -subject \
            | grep "CN=$domain" && echo "OK" || echo "FAIL";
        done
      '')

      # Diagnostic script to check certificate sync status
      (pkgs.writeShellScriptBin "check-cert-sync-status" ''
        echo "=== Certificate Sync Status Check ==="
        echo
        echo "Available certificates in ${cfg.certPath}:"
        for dir in ${cfg.certPath}/*; do
          if [[ ! -d "$dir" ]]; then continue; fi;
          domain=$(basename "$dir")
          if [[ "$domain" == "acme-challenge" ]]; then continue; fi;
          
          echo "  - $domain"
          
          # Check if cert files exist
          if [[ -f "$dir/fullchain.pem" && -f "$dir/key.pem" ]]; then
            # Get cert expiry
            expiry=$(${pkgs.openssl}/bin/openssl x509 -in "$dir/fullchain.pem" -noout -enddate 2>/dev/null | cut -d= -f2)
            echo "    Expiry: $expiry"
            
            # Get Subject Alternative Names
            sans=$(${pkgs.openssl}/bin/openssl x509 -in "$dir/fullchain.pem" -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -n1 | sed 's/^[[:space:]]*//')
            echo "    SANs: $sans"
          else
            echo "    ERROR: Missing cert files!"
          fi
          echo
        done

        echo "=== Failover Redirects Config Status ==="
        if [[ -f ${cfg.outputConfigPath} ]]; then
          echo "Config file exists: ${cfg.outputConfigPath}"
          echo "Server blocks configured:"
          grep -c "server {" ${cfg.outputConfigPath} || echo "0"
          echo
          echo "Domains configured:"
          grep "server_name" ${cfg.outputConfigPath} | awk '{print "  - " $2}' | sed 's/;//'
        else
          echo "ERROR: Config file not found at ${cfg.outputConfigPath}"
        fi
      '')
    ];
  };
}
