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
    systemd.services.failover-redirects-generate = {
      description = "Generate Nginx Failover Redirects Config";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScriptBin "failover-redirects-generate" ''
          mkdir -p $(dirname ${cfg.outputConfigPath})
          touch ${cfg.outputConfigPath}
          set -e
          tmpfile=$(mktemp)
          echo "map \$host \$redirect_target {" > $tmpfile
          echo "    default \"\";" >> $tmpfile
          for dir in /var/lib/acme/*; do
            domain=$(basename "$dir")
            skip=0
            for exclude in ${lib.concatStringsSep " " cfg.excludeDomains}; do
              if [ "$domain" = "$exclude" ]; then
                skip=1
                break
              fi
            done
            if [ "$skip" -eq 0 ]; then
              echo "    $domain ${cfg.statusPageDomain};" >> $tmpfile
            fi
          done
          echo "}" >> $tmpfile

          # Server block
          echo "server {" >> $tmpfile
          echo "    listen 443 ssl;" >> $tmpfile
          echo "    server_name _failover_domains $(ls /var/lib/acme | grep -v -E "^(acme-challenge|${lib.concatStringsSep "|" cfg.excludeDomains})$");" >> $tmpfile
          echo "    ssl_certificate /var/lib/acme/\$host/fullchain.pem;" >> $tmpfile
          echo "    ssl_certificate_key /var/lib/acme/\$host/key.pem;" >> $tmpfile
          echo "    location / {" >> $tmpfile
          echo "        if (\$redirect_target != \"\") {" >> $tmpfile
          echo "            return 302 https://${cfg.statusPageDomain}\$request_uri;" >> $tmpfile
          echo "        }" >> $tmpfile
          echo "        return 404;" >> $tmpfile
          echo "    }" >> $tmpfile
          echo "}" >> $tmpfile

          mv $tmpfile ${cfg.outputConfigPath}
        ''}/bin/failover-redirects-generate";
      };
    };

    systemd.paths.failover-redirects-generate = {
      description = "Watch /var/lib/acme for cert changes to regenerate failover config";
      pathConfig = {
        PathModified = "/var/lib/acme";
      };
      wantedBy = [ "multi-user.target" ];
    };

    # Nginx reload when config changes (optional safety net)
    systemd.services.nginx-reload-on-failover-change = {
      description = "Reload Nginx when failover-redirects.conf changes";
      path = [ pkgs.inotify-tools pkgs.bash ];
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScriptBin "nginx-reload-on-failover-change" ''
          mkdir $(dirname ${cfg.outputConfigPath})
          touch ${cfg.outputConfigPath}
          ${pkgs.inotify-tools}/bin/inotifywait -m -e modify ${cfg.outputConfigPath} | while read; do
            systemctl reload nginx
          done
        ''}/nginx-reload-on-failover-change";
        Restart = "always";
      };
      wantedBy = [ "multi-user.target" ];
    };

    services.nginx.enable = lib.mkDefault true;
    services.nginx.appendHttpConfig = ''
      include ${cfg.outputConfigPath};
    '';
  };
}
