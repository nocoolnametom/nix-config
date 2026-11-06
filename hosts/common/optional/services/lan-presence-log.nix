# LAN presence log: who is on the network, minute by minute.
#
# An arp-scan of the local subnet on a timer. Each run appends the full
# "timestamp, MAC, IP, vendor" table to a daily file and, by comparing against the
# previous run, writes "appeared", "vanished" and "moved to a new IP" lines to
# events.log. Lined up with smokeping this shows when a device fell off the network,
# how long it stayed off, and whether it came back with a different address (which
# points at DHCP rather than radio trouble).
#
# Noise to expect: phones and laptops that sleep will appear and vanish on their own.
# arp-scan retries each address so a single missed reply rarely shows as a vanish.
# Must run as root (raw sockets), which system units do by default.
#
# Files live in /var/lib/lan-presence-log:
#   scans/YYYY-MM-DD.tsv   every scan that day: time, mac, ip, vendor
#   events.log             appeared / vanished / moved lines
#   current.tsv, previous.tsv   working state for the diff
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.lan-presence-log;
  # Tools by store path so the script never depends on the unit's PATH.
  arpScan = "${pkgs.arp-scan}/bin/arp-scan";
  awk = "${pkgs.gawk}/bin/awk";
  find = "${pkgs.findutils}/bin/find";
  coreutils = "${pkgs.coreutils}/bin";
in
{
  options.services.lan-presence-log = {
    enable = lib.mkEnableOption "periodic arp-scan log of devices present on the LAN";

    interface = lib.mkOption {
      type = lib.types.str;
      example = "end0";
      description = ''
        Interface whose subnet is scanned. Set it explicitly: on a Docker host arp-scan's
        own guess can land on a bridge interface.
      '';
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "1min";
      description = "How often to scan (systemd OnUnitActiveSec syntax).";
    };

    retentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 90;
      description = "Daily scan files older than this are deleted. events.log is kept.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.lan-presence-log = {
      description = "Record which devices answer ARP on the LAN";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "lan-presence-log";
        TimeoutStartSec = "120";
      };
      script = ''
        set -u

        scanTime=$(${coreutils}/date -Is)
        scanDay=$(${coreutils}/date +%F)
        scansDirectory="$STATE_DIRECTORY/scans"
        currentTable="$STATE_DIRECTORY/current.tsv"
        previousTable="$STATE_DIRECTORY/previous.tsv"
        eventsLog="$STATE_DIRECTORY/events.log"
        ${coreutils}/mkdir -p "$scansDirectory"

        logEvent() {
          printf '%s %s\n' "$scanTime" "$*" >> "$eventsLog"
        }

        # arp-scan --plain prints "ip<TAB>mac<TAB>vendor" with no header or footer.
        # Re-order to mac first so the diff below keys on the hardware address, and keep
        # one line per MAC (a device answering from two IPs is rare and not what we track).
        ${arpScan} --localnet --interface="${cfg.interface}" --plain --retry=3 2>/dev/null \
          | ${awk} -F'\t' '{ print $2 "\t" $1 "\t" $3 }' \
          | ${coreutils}/sort -u -k1,1 > "$currentTable.new"

        if [ ! -s "$currentTable.new" ]; then
          # An empty scan is far more likely to be our own problem than an empty LAN.
          # Do not record a mass vanish; just note it and keep the previous table.
          logEvent "scan returned nothing; skipped (interface ${cfg.interface} down?)"
          ${coreutils}/rm -f "$currentTable.new"
          exit 0
        fi
        ${coreutils}/mv "$currentTable.new" "$currentTable"

        ${awk} -v now="$scanTime" -F'\t' '{ print now "\t" $0 }' "$currentTable" \
          >> "$scansDirectory/$scanDay.tsv"

        if [ -e "$previousTable" ]; then
          # Appeared: in current, not in previous.
          ${coreutils}/join -t "$(printf '\t')" -v 2 "$previousTable" "$currentTable" \
            | while IFS=$'\t' read -r mac ip vendor; do
                logEvent "appeared  $mac $ip $vendor"
              done
          # Vanished: in previous, not in current.
          ${coreutils}/join -t "$(printf '\t')" -v 1 "$previousTable" "$currentTable" \
            | while IFS=$'\t' read -r mac ip vendor; do
                logEvent "vanished  $mac $ip $vendor"
              done
          # Moved: in both, different IP.
          ${coreutils}/join -t "$(printf '\t')" "$previousTable" "$currentTable" \
            | ${awk} -F'\t' '$2 != $4 { print $1 "\t" $2 "\t" $4 "\t" $5 }' \
            | while IFS=$'\t' read -r mac oldIp newIp vendor; do
                logEvent "moved     $mac $oldIp -> $newIp $vendor"
              done
        fi
        ${coreutils}/cp "$currentTable" "$previousTable"

        ${find} "$scansDirectory" -name '*.tsv' -mtime +${toString cfg.retentionDays} -delete
      '';
    };

    systemd.timers.lan-presence-log = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = cfg.interval;
        Unit = "lan-presence-log.service";
      };
    };
  };
}
