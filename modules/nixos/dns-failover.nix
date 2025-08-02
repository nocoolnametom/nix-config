{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.dnsFailover;
in
{
  options.services.dnsFailover = {
    enable = mkEnableOption "Enable DNS failover health check";

    healthUrl = mkOption {
      type = types.str;
      description = "The health check URL to monitor (e.g., https://health.nocoolnametom.com)";
    };

    statusPageUrl = mkOption {
      type = types.str;
      description = "URL to the status page (e.g., https://status.doggett.family)";
    };

    failoverDomain = mkOption {
      type = types.str;
      description = "The domain whose A/AAAA records should be updated during failover (e.g., home.nocoolnametom.com)";
    };

    targetServerName = mkOption {
      type = types.str;
      default = "bert";
      description = "The name of the server being health-checked (for logging/debug output)";
    };

    statusServerUrl = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "The hostname or URL of the status page server (used to resolve Bombadil's IPs dynamically)";
    };

    porkbunApiKeyFile = mkOption {
      type = types.path;
      description = "Path to the file containing Porkbun API key (can be a SOPS file path)";
    };

    porkbunApiSecretFile = mkOption {
      type = types.path;
      description = "Path to the file containing Porkbun API secret (can be a SOPS file path)";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.dnsFailoverCheck = {
      description = "DNS Failover Health Check";
      # Note that the api key and secrets are environment variables so we can use sops template and parameters
      script = "${pkgs.writeShellScript "dns-failover-check" ''
        set -e

        echo "[Failover] Checking health of ${cfg.targetServerName}..."

        if curl -s --max-time 10 --fail ${cfg.healthUrl} >/dev/null; then
          echo "[Failover] ${cfg.targetServerName} is UP. No action needed."
          exit 0
        else
          echo "[Failover] ${cfg.targetServerName} is DOWN. Checking DNS..."
        fi

        STATUS_SERVER_IPv4=$(${pkgs.dnsutils}/bin/dig +short A ${cfg.statusServerUrl} | head -n1)
        STATUS_SERVER_IPv6=$(${pkgs.dnsutils}/bin/dig +short AAAA ${cfg.statusServerUrl} | head -n1)

        RECORDS=$(curl -s -X POST "https://porkbun.com/api/json/v3/dns/retrieve/${cfg.failoverDomain}" \
          -H "Content-Type: application/json" \
          -d "{\"apikey\":\"$PORKBUN_API_KEY\", \"secretapikey\":\"$PORKBUN_SECRET\"}")

        CURRENT_IPv4=$(echo $RECORDS | ${pkgs.jq}/bin/jq -r '.records[] | select(.type=="A") | .content')
        CURRENT_IPv6=$(echo $RECORDS | ${pkgs.jq}/bin/jq -r '.records[] | select(.type=="AAAA") | .content')

        if [ "$CURRENT_IPv4" != "$STATUS_SERVER_IPv4" ]; then
          echo "[Failover] Updating A record to Status Server ($STATUS_SERVER_IPv4)"
          curl -s -X POST "https://porkbun.com/api/json/v3/dns/editByNameType/${cfg.failoverDomain}/A" \
            -H "Content-Type: application/json" \
            -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET\",\"content\":\"$STATUS_SERVER_IPv4\",\"ttl\":\"300\"}"
        fi

        if [ "$CURRENT_IPv6" != "$STATUS_SERVER_IPv6" ]; then
          echo "[Failover] Updating AAAA record to Status Server ($STATUS_SERVER_IPv6)"
          curl -s -X POST "https://porkbun.com/api/json/v3/dns/editByNameType/${cfg.failoverDomain}/AAAA" \
            -H "Content-Type: application/json" \
            -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET\",\"content\":\"$STATUS_SERVER_IPv6\",\"ttl\":\"300\"}"
        fi

        echo "[Failover] DNS failover complete."
      ''}/bin/dns-failover-check";
      serviceConfig.Type = "oneshot";
    };

    systemd.timers.dnsFailoverCheck = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "5min";
        AccuracySec = "30s";
      };
    };
  };
}
