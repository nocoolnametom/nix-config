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
      type = lib.types.listOf lib.types.str;
      default = "status.domain.name";
      description = "Domain to redirect the failovers to with a temporary redirect";
    };

    outputConfigPath = lib.mkOption {
      type = lib.types.path;
      default = "/etc/nginx/failover-redirects.conf";
      description = "Path to write the generated Nginx failover redirects config";
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

                    # Iterate domains in /var/lib/acme
                    for dir in /var/lib/acme/*; do
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
                      if [ ! -f "/var/lib/acme/$domain/fullchain.pem" ] || [ ! -f "/var/lib/acme/$domain/key.pem" ]; then
                        echo "Warning: cert files missing for $domain, skipping" >&2
                        continue
                      fi

                      # Output one server block per domain
                      cat >> $tmpfile <<EOF
          server {
              listen 443 ssl;
              listen [::]:443 ssl;
              server_name ${"$"}{domain};
              ssl_certificate /var/lib/acme/${"$"}{domain}/fullchain.pem;
              ssl_certificate_key /var/lib/acme/${"$"}{domain}/key.pem;

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
      description = "Watch /var/lib/acme for cert changes to regenerate failover config";
      pathConfig = {
        PathModified = "/var/lib/acme";
      };
      wantedBy = [ "multi-user.target" ];
      unitConfig = {
        Unit = "failover-redirects-generate.service";
      };
    };

    systemd.services.nginx-reload-on-failover-change = {
      description = "Reload Nginx when failover-redirects.conf changes";
      path = [ pkgs.inotify-tools pkgs.bash ];
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScriptBin "nginx-reload-on-failover-change" ''
          inotifywait -m -e modify ${cfg.outputConfigPath} | while read; do
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

        for domain in $(ls /var/lib/acme); do
          if [[ "$domain" == "acme-challenge" ]]; then continue; fi;

          echo -n "Testing $domain (IPv4) ... "
          ${pkgs.openssl}/bin/openssl s_client -connect $HOSTNAME:443 -servername "$domain" -4 < /dev/null 2>/dev/null \
            | ${pkgs.openssl}/bin/openssl x509 -noout -subject \
            | grep "CN=$domain" && echo "OK" || echo "FAIL";

          echo -n "Testing $domain (IPv6) ... "
          # Resolve IPv6 address from /etc/hosts or DNS
          IPV6_ADDR=$(getent ahosts $HOSTNAME | grep 'STREAM' | grep -oE '([0-9a-fA-F:]+:+)+[0-9a-fA-F]+' | grep ':' | head -n1)

          if [[ -z "$IPV6_ADDR" ]]; then
            echo "SKIP (No IPv6 found)"
            continue
          fi

          ${pkgs.openssl}/bin/openssl s_client -connect "[$IPV6_ADDR]:443" -servername "$domain" < /dev/null 2>/dev/null \
            | ${pkgs.openssl}/bin/openssl x509 -noout -subject \
            | grep "CN=$domain" && echo "OK" || echo "FAIL";
        done
      '')
    ];
  };
}
