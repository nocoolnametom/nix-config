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
      description = "The health check URL to monitor (e.g., https://health.domain.name)";
    };

    failoverDomain = mkOption {
      type = types.str;
      description = "The domain whose A/AAAA records should be updated during failover (e.g., status.domain.name)";
    };

    targetServerName = mkOption {
      type = types.str;
      default = "bert";
      description = "The name of the server being health-checked (for logging/debug output)";
    };

    statusServerUrl = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "The hostname or URL of the status page server (used to resolve failover server's IPs dynamically)";
    };

    porkbunApiKeyFile = mkOption {
      type = types.path;
      description = "Path to the file containing Porkbun API key (can be a SOPS file path)";
    };

    porkbunApiSecretFile = mkOption {
      type = types.path;
      description = "Path to the file containing Porkbun API secret (can be a SOPS file path)";
    };

    checkInterval = mkOption {
      type = types.str;
      default = "5min";
      description = "How often to run the health check (systemd time format)";
    };

    checkTimeout = mkOption {
      type = types.int;
      default = 10;
      description = "Timeout in seconds for each health check attempt";
    };

    requiredFailures = mkOption {
      type = types.int;
      default = 3;
      description = "Number of consecutive failures required before triggering DNS failover";
    };

    retryDelay = mkOption {
      type = types.int;
      default = 30;
      description = "Seconds to wait between retry attempts during a single check";
    };

    stateFile = mkOption {
      type = types.path;
      default = "/var/lib/dns-failover-state";
      description = "File to track consecutive failure count";
    };
  };

  config = mkIf cfg.enable {
    # Ensure state directory exists
    systemd.tmpfiles.rules = [
      "f ${cfg.stateFile} 0644 root root - 0"
    ];

    systemd.services.dnsFailoverCheck = {
      description = "DNS Failover Health Check";
      # Note that the api key and secrets are environment variables so we can use sops template and parameters
      script = "${pkgs.writeShellScript "dns-failover-check" ''
        set -e

        PORKBUN_API_KEY=`cat ${cfg.porkbunApiKeyFile}`
        PORKBUN_SECRET=`cat ${cfg.porkbunApiSecretFile}`
        STATE_FILE="${cfg.stateFile}"
        REQUIRED_FAILURES=${toString cfg.requiredFailures}
        RETRY_DELAY=${toString cfg.retryDelay}
        TIMEOUT=${toString cfg.checkTimeout}

        # Read current failure count
        if [ -f "$STATE_FILE" ]; then
          FAILURE_COUNT=$(cat "$STATE_FILE")
        else
          FAILURE_COUNT=0
        fi

        echo "[Failover] Checking health of ${cfg.targetServerName}... (consecutive failures: $FAILURE_COUNT/$REQUIRED_FAILURES)"

        # Try health check with retry
        HEALTH_CHECK_PASSED=false
        for attempt in $(seq 1 ${toString cfg.requiredFailures}); do
          if ${pkgs.curl}/bin/curl -s --max-time "$TIMEOUT" --fail ${cfg.healthUrl} >/dev/null 2>&1; then
            echo "[Failover] Health check passed on attempt $attempt"
            HEALTH_CHECK_PASSED=true
            break
          else
            echo "[Failover] Health check failed on attempt $attempt/${toString cfg.requiredFailures}"
            if [ $attempt -lt ${toString cfg.requiredFailures} ]; then
              echo "[Failover] Waiting $RETRY_DELAY seconds before retry..."
              sleep "$RETRY_DELAY"
            fi
          fi
        done

        if [ "$HEALTH_CHECK_PASSED" = true ]; then
          echo "[Failover] ${cfg.targetServerName} is UP. Resetting failure count."
          echo "0" > "$STATE_FILE"
          exit 0
        fi

        # Health check failed - increment failure count
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        echo "$FAILURE_COUNT" > "$STATE_FILE"

        echo "[Failover] ${cfg.targetServerName} is DOWN. Consecutive failures: $FAILURE_COUNT/$REQUIRED_FAILURES"

        # Only trigger DNS failover if we've reached the threshold
        if [ "$FAILURE_COUNT" -lt "$REQUIRED_FAILURES" ]; then
          echo "[Failover] Not yet triggering failover (need $REQUIRED_FAILURES consecutive failures)"
          exit 0
        fi

        echo "[Failover] Threshold reached! Triggering DNS failover..."

        STATUS_SERVER_IPv4=$(${pkgs.dnsutils}/bin/dig +short A ${cfg.statusServerUrl} | head -n1)
        STATUS_SERVER_IPv6=$(${pkgs.dnsutils}/bin/dig +short AAAA ${cfg.statusServerUrl} | head -n1)

        # Strip everything up to the last two dot-separated fields
        HOST="${cfg.failoverDomain}"
        DOMAIN=$(echo "$HOST" | ${pkgs.gawk}/bin/awk -F. '{if (NF>2) print $(NF-1)"."$NF; else print $0}')
        SUBDOMAIN=""
        if [ "$HOST" != "$DOMAIN" ]; then
          SUBDOMAIN="/${"$"}{HOST%.$DOMAIN}"
        fi

        RECORDS=$(${pkgs.curl}/bin/curl -s -X POST "https://api.porkbun.com/api/json/v3/dns/retrieve/$DOMAIN" \
          -H "Content-Type: application/json" \
          -d "{\"apikey\":\"$PORKBUN_API_KEY\", \"secretapikey\":\"$PORKBUN_SECRET\"}")

        CURRENT_IPv4=$(echo $RECORDS | ${pkgs.jq}/bin/jq -r '.records[] | select(.name=="${cfg.failoverDomain}" and .type=="A") | .content')
        CURRENT_IPv6=$(echo $RECORDS | ${pkgs.jq}/bin/jq -r '.records[] | select(.name=="${cfg.failoverDomain}" and .type=="AAAA") | .content')

        if [ "$CURRENT_IPv4" != "$STATUS_SERVER_IPv4" ]; then
          echo "[Failover] Updating A record to Status Server ($STATUS_SERVER_IPv4)"
          ${pkgs.curl}/bin/curl -s -X POST "https://api.porkbun.com/api/json/v3/dns/editByNameType/$DOMAIN/A$SUBDOMAIN" \
            -H "Content-Type: application/json" \
            -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET\",\"content\":\"$STATUS_SERVER_IPv4\",\"ttl\":\"300\"}"
        fi

        if [ "$CURRENT_IPv6" != "$STATUS_SERVER_IPv6" ]; then
          echo "[Failover] Updating AAAA record to Status Server ($STATUS_SERVER_IPv6)"
          ${pkgs.curl}/bin/curl -s -X POST "https://api.porkbun.com/api/json/v3/dns/editByNameType/$DOMAIN/AAAA$SUBDOMAIN" \
            -H "Content-Type: application/json" \
            -d "{\"apikey\":\"$PORKBUN_API_KEY\",\"secretapikey\":\"$PORKBUN_SECRET\",\"content\":\"$STATUS_SERVER_IPv6\",\"ttl\":\"300\"}"
        fi

        echo "[Failover] DNS failover complete."
      ''}";
      serviceConfig.Type = "oneshot";
    };

    systemd.timers.dnsFailoverCheck = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = cfg.checkInterval;
        AccuracySec = "30s";
      };
    };

    # Helper script to manually reset the failure count
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "reset-dns-failover-count" ''
        echo "Resetting DNS failover failure count..."
        echo "0" > ${cfg.stateFile}
        echo "Failure count reset to 0"
        echo "Current status:"
        cat ${cfg.stateFile}
      '')

      (pkgs.writeShellScriptBin "check-dns-failover-status" ''
        if [ -f ${cfg.stateFile} ]; then
          FAILURES=$(cat ${cfg.stateFile})
          echo "DNS Failover Status:"
          echo "  Consecutive failures: $FAILURES/${toString cfg.requiredFailures}"
          echo "  Check interval: ${cfg.checkInterval}"
          echo "  Required failures: ${toString cfg.requiredFailures}"
          echo "  Timeout per check: ${toString cfg.checkTimeout}s"
          echo "  Retry delay: ${toString cfg.retryDelay}s"
          echo ""
          if [ "$FAILURES" -ge "${toString cfg.requiredFailures}" ]; then
            echo "  ⚠️  FAILOVER ACTIVE - DNS pointing to status server"
          elif [ "$FAILURES" -gt 0 ]; then
            echo "  ⚠️  WARNING - $FAILURES consecutive failure(s) detected"
          else
            echo "  ✓ OK - No failures detected"
          fi
        else
          echo "State file not found. Failover may not have run yet."
        fi
        echo ""
        echo "Last check:"
        ${pkgs.systemd}/bin/journalctl -u dnsFailoverCheck.service -n 20 --no-pager
      '')
    ];
  };
}
