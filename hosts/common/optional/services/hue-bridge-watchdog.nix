# Hue bridge watchdog
#
# The Hue Bridge Pro sits on Wi-Fi and now and then drops off the network. This
# timer probes it from a wired, always-on host and, when it stays unreachable,
# asks the Hubitat to power-cycle the Zigbee plug the bridge's charger is on.
#
# Flow, once per timer tick:
#   1. GET https://<bridge>/api/0/config (unauthenticated, self-signed cert).
#      Reachable: clear any outage marker and stop.
#   2. Unreachable: wait and re-probe a few times so a short blip that hits the
#      whole LAN does not trigger a power cycle.
#   3. Still down and the Hubitat is also unreachable: treat it as a general
#      network outage. We could not send the power cycle anyway, so just log it.
#   4. Still down, Hubitat reachable, no outage marker yet: write the marker, hit
#      the Hubitat Rule Machine local endpoint (its action is "off, wait 2 s, on"),
#      wait for the bridge to boot, probe again.
#   5. Recovered: clear the marker. Not recovered: exit 1. The marker stays, so
#      later ticks stay quiet until the bridge comes back on its own, and the
#      non-zero exit is what fires the systemd-failure-alert Pushover message.
#
# Every decision is appended to /var/lib/hue-bridge-watchdog/events.log so the
# outage history can be lined up against smokeping and the LAN presence log.
{
  lib,
  config,
  pkgs,
  configVars,
  ...
}:
let
  cfg = config.services.hue-bridge-watchdog;
  # Tools by store path so the script never depends on the unit's PATH.
  curl = "${pkgs.curl}/bin/curl";
  grep = "${pkgs.gnugrep}/bin/grep";
  coreutils = "${pkgs.coreutils}/bin";
in
{
  options.services.hue-bridge-watchdog = {
    enable = lib.mkEnableOption "Hue bridge reachability watchdog with Hubitat power cycle";

    bridgeAddress = lib.mkOption {
      type = lib.types.str;
      default = configVars.networking.subnets.hueBridge.ip;
      defaultText = lib.literalExpression "configVars.networking.subnets.hueBridge.ip";
      description = "IP address of the Hue bridge to probe.";
    };

    hubitatAddress = lib.mkOption {
      type = lib.types.str;
      default = configVars.networking.subnets.hubitat.ip;
      defaultText = lib.literalExpression "configVars.networking.subnets.hubitat.ip";
      description = ''
        IP address of the Hubitat hub. Only used as a second reachability check: if the
        Hubitat is down too, the problem is wider than the Hue bridge and no power cycle
        is attempted.
      '';
    };

    powerCycleUrlFile = lib.mkOption {
      type = lib.types.str;
      default = config.sops.secrets."hubitat/hue_power_cycle_url".path;
      defaultText = lib.literalExpression ''config.sops.secrets."hubitat/hue_power_cycle_url".path'';
      description = ''
        File holding the full Hubitat Rule Machine local endpoint URL (including its
        access token) whose rule turns the bridge's plug off, waits two seconds, and turns
        it back on. Fetched with a plain HTTP GET.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "5min";
      description = "How often the probe runs (systemd OnUnitActiveSec syntax).";
    };

    attempts = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Probes (first one included) before the bridge counts as down.";
    };

    retryDelaySeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Seconds between probes while deciding whether the bridge is down.";
    };

    recoveryWaitSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 90;
      description = "Seconds to give the bridge to boot after a power cycle before the final probe.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."hubitat/hue_power_cycle_url" = { };

    systemd.services.hue-bridge-watchdog = {
      description = "Probe the Hue bridge and power-cycle it via Hubitat when it stays unreachable";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "hue-bridge-watchdog";
        # Worst case: (attempts - 1) retries plus the boot wait plus curl timeouts.
        TimeoutStartSec = toString (
          (cfg.attempts - 1) * cfg.retryDelaySeconds + cfg.recoveryWaitSeconds + 120
        );
      };
      script = ''
        set -u

        bridgeAddress="${cfg.bridgeAddress}"
        hubitatAddress="${cfg.hubitatAddress}"
        outageMarker="$STATE_DIRECTORY/outage-in-progress"
        eventsLog="$STATE_DIRECTORY/events.log"

        logEvent() {
          printf '%s %s\n' "$(${coreutils}/date -Is)" "$*" | ${coreutils}/tee -a "$eventsLog"
        }

        bridgeIsUp() {
          # The bridge answers this path without an API key. Plain HTTP only 301s to HTTPS,
          # and the HTTPS cert is self-signed, so go straight to HTTPS and skip verification.
          ${curl} -sk --max-time 5 --fail "https://$bridgeAddress/api/0/config" 2>/dev/null \
            | ${grep} -q '"bridgeid"'
        }

        hubitatIsUp() {
          ${curl} -s --max-time 5 -o /dev/null "http://$hubitatAddress/"
        }

        if bridgeIsUp; then
          if [ -e "$outageMarker" ]; then
            logEvent "bridge reachable again; outage that began $(${coreutils}/cat "$outageMarker") is over"
            ${coreutils}/rm -f "$outageMarker"
          fi
          exit 0
        fi

        if [ -e "$outageMarker" ]; then
          # Already power-cycled this outage and alerted. Stay quiet until it recovers.
          echo "bridge still unreachable; power cycle already sent $(${coreutils}/cat "$outageMarker"), waiting"
          exit 0
        fi

        attempt=1
        while [ "$attempt" -lt ${toString cfg.attempts} ]; do
          ${coreutils}/sleep ${toString cfg.retryDelaySeconds}
          attempt=$((attempt + 1))
          if bridgeIsUp; then
            logEvent "bridge answered on probe $attempt of ${toString cfg.attempts}; transient blip, no action"
            exit 0
          fi
        done

        if ! hubitatIsUp; then
          logEvent "bridge AND Hubitat unreachable after ${toString cfg.attempts} probes; general network outage, not power cycling"
          exit 0
        fi

        logEvent "bridge unreachable after ${toString cfg.attempts} probes, Hubitat is up; requesting power cycle"
        ${coreutils}/date -Is > "$outageMarker"

        if ! ${curl} -s --fail --max-time 10 -o /dev/null "$(${coreutils}/cat ${cfg.powerCycleUrlFile})"; then
          logEvent "power cycle request to the Hubitat failed"
          exit 1
        fi

        ${coreutils}/sleep ${toString cfg.recoveryWaitSeconds}

        if bridgeIsUp; then
          logEvent "bridge recovered ${toString cfg.recoveryWaitSeconds}s after power cycle"
          ${coreutils}/rm -f "$outageMarker"
          exit 0
        fi

        logEvent "bridge still unreachable after power cycle; giving up until it returns on its own"
        exit 1
      '';
    };

    systemd.timers.hue-bridge-watchdog = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = cfg.interval;
        Unit = "hue-bridge-watchdog.service";
      };
    };

    # A non-zero exit after a failed power cycle is the alert path, via the existing notifier.
    services.systemd-failure-alert.additional-services =
      lib.mkIf config.services.systemd-failure-alert.enable
        [
          "hue-bridge-watchdog"
        ];
  };
}
