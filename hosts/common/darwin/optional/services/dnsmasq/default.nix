{
  lib,
  pkgs,
  config,
  configVars,
  ...
}:
let
  outputDir = "/etc/dnsmasq.d";
  outputName = "${outputDir}/tailscale.hosts";
  # build the updater into the Nix store (uses jq from pkgs)
  tailscaleUpdater = pkgs.writeShellScriptBin "tailscale-updater" ''
    #!/usr/bin/env bash
    set -euo pipefail

    NAMES_FILE="${pkgs.writeText "tailscale-names.txt" ''
      ${configVars.networking.workDnsmasq.machineName}
    ''}"
    DOMAINS_FILE="${pkgs.writeText "tailscale-domains.txt" ''
      ${lib.concatStringsSep "\n" configVars.networking.workDnsmasq.domains}
    ''}"
    OUT_DIR="${outputDir}"
    OUT_FILE="${outputName}"
    TMP="$(mktemp)"

    if [ "$(id -u)" -ne 0 ]; then
      echo "must run as root" >&2
      exit 1
    fi

    mkdir -p "''${OUT_DIR}"

    [[ -e "''${NAMES_FILE}" && -r "''${NAMES_FILE}" ]] || { echo "no names file ''${NAMES_FILE}, nothing to do"; exit 0; }
    [[ -e "''${DOMAINS_FILE}" && -r "''${DOMAINS_FILE}" ]] || { echo "no domains file ''${DOMAINS_FILE}, nothing to do"; exit 0; }

    names="$(awk 'NF && $1 !~ /^#/ {print $1}' "''${NAMES_FILE}" | sort -u)"
    domains="$(awk 'NF && $1 !~ /^#/ {print $1}' "''${DOMAINS_FILE}" | sort -u)"

    [ -z "''${names}" ] && { echo "no names"; exit 0; }

    launchd_label="${config.launchd.daemons.dnsmasq.serviceConfig.Label}"

    status_json="$(mktemp)"
    ${config.services.tailscale.package}/bin/tailscale status --json > "''${status_json}" 2>/dev/null || true

    > "''${TMP}"
    for name in ''${names}; do
      ip="$(${pkgs.jq}/bin/jq -r --arg name "''${name}" '
        (.Peer // {})[]?
        | select(.HostName == $name)
        | (.TailscaleIPs[]? // empty)
        | select(test("^[0-9]+(\\.[0-9]+){3}$"))
        ' "''${status_json}" 2>/dev/null | head -n1 || true)"

      if [ -z "''${ip}" ]; then
        echo "no ip for ''${name}; skipping" >&2
        continue
      fi

      echo "found ip ''${ip} for name ''${name}" >&2

      line="''${ip} ''${name}"
      for d in ''${domains}; do
        line="''${line} ''${d}"
      done
      echo "''${line}" >> "''${TMP}"
    done

    rm -f "''${status_json}"

    if [ -s "''${TMP}" ]; then
      sort -u "''${TMP}" -o "''${TMP}"
    fi

    touch "''${OUT_FILE}" || true

    chmod 755 "''${OUT_FILE}" || true

    reload_dnsmasq() {
      if command -v launchctl >/dev/null 2>&1; then
        echo "attempting launchctl kickstart -k system/''${launchd_label}" >&2
        if launchctl kickstart -k "system/''${launchd_label}" >/dev/null 2>&1; then
          echo "reload via launchctl succeeded" >&2
          return 0
        else
          echo "launchctl reload failed; falling back to SIGHUP" >&2
        fi
      fi

      if pgrep -x dnsmasq >/dev/null 2>&1; then
        pkill -HUP -x dnsmasq || true
        echo "reloaded dnsmasq via SIGHUP" >&2
      else
        echo "dnsmasq not running; skipping reload" >&2
      fi
    }

    if ! cmp -s "''${TMP}" "''${OUT_FILE}" 2>/dev/null; then
      mv "''${TMP}" "''${OUT_FILE}"
      chmod 755 "''${OUT_FILE}" || true
      echo "$(date -u) - updated ''${OUT_FILE}; reloading dnsmasq" >&2
      reload_dnsmasq
    else
      rm -f "''${TMP}"
      echo "$(date -u) - no change" >&2
    fi
  '';
in
{
  services.dnsmasq.enable = lib.mkDefault true;
  # I used to set these here, but the values are now dynamically looked up from tailscale
  # If you need to set others this would be the place to do so
  # services.dnsmasq.addresses = configVars.networking.workDnsmasq.addresses;

  environment.etc =
    (builtins.listToAttrs (
      builtins.map (domain: {
        name = "resolver/${domain}";
        value = {
          enable = true;
          text = ''
            port ${toString config.services.dnsmasq.port}
            nameserver ${config.services.dnsmasq.bind}
          '';
        };
      }) (configVars.networking.workDnsmasq.domains)
    ))
    // {
      # Load the generated configs
      "dnsmasq.conf".text = ''
        # load all config snippets from the directory
        conf-dir=/etc/dnsmasq.d
      '';
      # ensure dnsmasq loads the generated hosts file
      "dnsmasq.d/tailscale.conf".text = ''
        addn-hosts=${outputName}
      '';
    };

  # declare a nix-darwin launchd job (no plist file needed)
  launchd.daemons.tailscale-dnsmasq-updater = {
    serviceConfig = {
      Program = "${tailscaleUpdater}/bin/tailscale-updater";
      ProgramArguments = [ ];
      RunAtLoad = true;
      StartInterval = 60;
      StandardOutPath = "/var/log/tailscale-dnsmasq-updater.log";
      StandardErrorPath = "/var/log/tailscale-dnsmasq-updater.log";
    };
  };

  # activation: ensure runtime dirs/files exist with sane perms
  system.activationScripts.tailscaleDnsmasqUpdater = {
    text = ''
      #!/bin/sh
      set -euo pipefail

      install -d -m0755 /etc/dnsmasq.d
    '';
  };
}
