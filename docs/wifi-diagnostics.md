# Wi-Fi flakiness investigation

**Started:** 2026-11-06 on estel. **Review the data on or after 2026-11-20** (two weeks of
collection), then decide whether the cause is the Hue bridge, one mesh node, or the main hub.

## Why

The Hue Bridge Pro, which is on Wi-Fi, drops off the network now and then. It is not clear
whether the bridge itself hangs or the mesh Wi-Fi is dropping clients. estel is wired to the
mesh's main hub, so it watches the wireless devices from the outside. A wired host cannot see
the radio layer; what it can see is which devices fail together and when, which is usually
enough to point at the culprit.

## What is collecting data (all on estel)

| Module | Unit | Data |
|---|---|---|
| `hosts/common/optional/services/homelab-smokeping.nix` | `smokeping.service` | Latency and loss graphs per target, 1-minute steps. Web UI: `http://estel:8089/` on the LAN, served by Caddy (nginx must stay off on estel). RRDs in `/var/lib/smokeping/data`. |
| `hosts/common/optional/services/lan-presence-log.nix` | `lan-presence-log.timer` (every minute) | `/var/lib/lan-presence-log/events.log` has `appeared` / `vanished` / `moved` lines per MAC. `scans/YYYY-MM-DD.tsv` has every full scan. |
| `hosts/common/optional/services/hue-bridge-watchdog.nix` | `hue-bridge-watchdog.timer` (every 5 min) | `/var/lib/hue-bridge-watchdog/events.log` records every outage decision: transient blip, general outage, power cycle sent, recovered, gave up. A failed power cycle also sends the usual Pushover service-failure alert. |

Target IPs come from `configVars.networking.subnets.*` in nix-secrets (`hueBridge`, `hubitat`,
`router`, `feanor`). The Hubitat power-cycle URL is the sops key `hubitat/hue_power_cycle_url`.

## How to read it

1. Open smokeping and look at the loss (the colour under the line) across all targets for the
   same window.
   - **Only the Hue bridge** loses packets: the bridge or its own radio is the problem. The
     watchdog is the right fix.
   - **Several wireless devices together, wired targets fine:** the mesh. If they all hang off
     one satellite, that node's backhaul; if every wireless device drops, the main hub's radio
     (channel change, band steering, firmware reboot).
   - **Wired targets or the Internet targets drop too:** not Wi-Fi at all.
2. Take the timestamps of the drops from smokeping or the presence log and look them up in the
   mesh system's own event log. DFS channel hops, reboots and band-steering events only show up
   there.
3. In the presence log, a `moved` line right after a `vanished`/`appeared` pair means the device
   came back with a new IP. That points at DHCP leases, not radio.
4. Line up `hue-bridge-watchdog/events.log` with the above to see whether the bridge was ever
   the *only* thing down.

Quick looks:

```bash
ssh estel 'grep -v "^$" /var/lib/hue-bridge-watchdog/events.log | tail -50'
ssh estel 'grep -c vanished /var/lib/lan-presence-log/events.log; tail -50 /var/lib/lan-presence-log/events.log'
```

## Still to do

- Add each mesh satellite node and two or three always-home Wi-Fi clients to the smokeping
  target list in `hosts/estel/default.nix` once their IPs are in nix-secrets. Without them,
  smokeping can tell "bridge only" from "something wider" but not "one node" from "whole radio".
- Confirm in the Hubitat that the Rule Machine local endpoint rule is "plug off, wait 2 s, plug
  on", and that the Hue bridge's charger is really on that plug.
- If the mesh offers a dedicated 2.4 GHz IoT network, moving the Hue bridge there is the
  cheapest experiment and often the whole fix.
- When the investigation is over, decide which of the three collectors to keep. The watchdog
  is useful permanently; smokeping is cheap to keep; the presence log can go.
