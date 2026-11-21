# Confine selected systemd services to a network namespace whose only route out
# is a Proton VPN WireGuard tunnel.
#
# Layout:
#   proton-vpn-netns.service    creates the namespace and the WireGuard interface
#                               inside it (no peer yet, so nothing can leave).
#   proton-vpn-tunnel.service   signs in to Proton, picks a server and loads its
#                               peer config into the interface. Runs at boot and
#                               then every `refreshInterval` to renew the key's
#                               certificate (it stays on the same server while
#                               that server is healthy).
#   proton-vpn-watchdog.timer   checks the WireGuard handshake every minute; if
#                               it goes stale, marks the server bad and switches
#                               servers. The watchdog unit fails (and so trips
#                               any failure alerting) once the tunnel has been
#                               down for `alertAfter`.
#   proton-vpn-portforward      optional: keeps a NAT-PMP port mapping alive and
#                               runs a hook whenever the forwarded port changes.
#
# Confined services only see `lo` and the tunnel. If the tunnel is down they
# have no network at all; nothing falls back to the host's uplink. DNS goes
# to the VPN's resolver through the tunnel, and the host's nscd and
# systemd-resolved sockets are hidden from them so lookups can't escape that way.
# `forwardPorts` exposes TCP ports of confined services on the host (via
# systemd-socket-proxyd), so local clients keep using the usual host:port.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.services.proton-vpn-netns;

  ns = cfg.namespace;
  ifname = cfg.interface;
  nsPath = "/run/netns/${ns}";
  stateDir = "/var/lib/proton-vpn-netns";
  runDir = "/run/proton-vpn-netns";

  resolvConf = pkgs.writeText "proton-vpn-netns-resolv.conf" ''
    nameserver ${cfg.dns}
    options edns0
  '';

  confgenArgs = lib.escapeShellArgs (
    [
      "--state-dir"
      stateDir
      "--username-file"
      cfg.usernameFile
      "--password-file"
      cfg.passwordFile
      "--country"
      cfg.country
      "--exclude-file"
      "${stateDir}/bad-servers"
      "--output"
      "${runDir}/wg.conf"
      "--info"
      "${stateDir}/server.json"
    ]
    ++ lib.optionals (cfg.totpSecretFile != null) [
      "--totp-secret-file"
      cfg.totpSecretFile
    ]
    ++ lib.optionals (cfg.city != null) [
      "--city"
      cfg.city
    ]
    ++ lib.optional cfg.p2p "--p2p"
    ++ lib.optional cfg.portForwarding.enable "--port-forwarding"
    ++ lib.optional cfg.moderateNat "--moderate-nat"
  );

  confinement = {
    bindsTo = [ "proton-vpn-netns.service" ];
    after = [ "proton-vpn-netns.service" ];
    # Restart along with the namespace, so a service never keeps running in a
    # namespace that has been torn down and recreated.
    partOf = [ "proton-vpn-netns.service" ];
    serviceConfig = {
      NetworkNamespacePath = nsPath;
      BindReadOnlyPaths = [ "${resolvConf}:/etc/resolv.conf" ];
      # Both of these resolve names in the host namespace, i.e. outside the tunnel.
      InaccessiblePaths = [
        "-/run/nscd"
        "-/run/systemd/resolve/io.systemd.Resolve"
      ];
    };
  };
in
{
  options.services.proton-vpn-netns = {
    enable = mkEnableOption "confining services to a Proton VPN WireGuard network namespace";

    package = mkOption {
      type = types.package;
      default = pkgs.proton-wg-confgen;
      defaultText = lib.literalExpression "pkgs.proton-wg-confgen";
      description = "Package providing `proton-wg-confgen`.";
    };

    namespace = mkOption {
      type = types.str;
      default = "protonvpn";
      description = "Name of the network namespace (as used by `ip netns`).";
    };

    interface = mkOption {
      type = types.str;
      default = "wg-proton";
      description = "Name of the WireGuard interface inside the namespace.";
    };

    usernameFile = mkOption {
      type = types.str;
      description = "File containing the Proton account username or email.";
    };

    passwordFile = mkOption {
      type = types.str;
      description = "File containing the Proton account password.";
    };

    totpSecretFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "File containing the base32 TOTP secret, if the account uses 2FA.";
    };

    country = mkOption {
      type = types.str;
      default = "US";
      description = "Two-letter code of the exit country.";
    };

    city = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional exit city; any city in `country` when null.";
    };

    p2p = mkOption {
      type = types.bool;
      default = true;
      description = "Only use servers that allow P2P traffic.";
    };

    moderateNat = mkOption {
      type = types.bool;
      default = true;
      description = "Request moderate (less strict) NAT, which helps peer-to-peer connectivity.";
    };

    address = mkOption {
      type = types.str;
      default = "10.2.0.2/32";
      description = "Tunnel address Proton assigns to WireGuard clients.";
    };

    dns = mkOption {
      type = types.str;
      default = "10.2.0.1";
      description = "DNS resolver reachable through the tunnel.";
    };

    mtu = mkOption {
      type = types.int;
      default = 1420;
      description = "MTU of the WireGuard interface.";
    };

    refreshInterval = mkOption {
      type = types.str;
      default = "6h";
      description = ''
        How often to renew the WireGuard key's certificate and refresh the server
        list. Certificates are valid for about 7 days.
      '';
    };

    handshakeTimeout = mkOption {
      type = types.int;
      default = 300;
      description = ''
        Seconds without a WireGuard handshake after which the server is considered
        dead and another one is chosen. Handshakes happen about every 2 minutes.
      '';
    };

    alertAfter = mkOption {
      type = types.int;
      default = 1800;
      description = "Seconds of continuous tunnel outage after which the watchdog unit fails.";
    };

    confinedServices = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "deluged" ];
      description = "systemd services (without `.service`) to run inside the namespace.";
    };

    forwardPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
      example = [ 58846 ];
      description = ''
        TCP ports of confined services to expose on the host, on all addresses.
        Connections are proxied to 127.0.0.1:<port> inside the namespace.
      '';
    };

    portForwarding = {
      enable = mkEnableOption "keeping a Proton NAT-PMP port forward open";

      hook = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Shell commands run inside the namespace (as root) when the forwarded
          port is first obtained or changes, and periodically after that. The port
          is in `$PORT`. A non-zero exit makes it retry on the next renewal.
        '';
      };

      hookPath = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Packages added to the hook's PATH.";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services = lib.mkMerge [
      {
        proton-vpn-netns = {
          description = "Network namespace for Proton VPN-confined services";
          wantedBy = [ "multi-user.target" ];
          before = [ "network-pre.target" ];
          path = [
            pkgs.iproute2
            pkgs.procps
          ];
          # Recreating the namespace would restart every confined service; only
          # do that on an explicit restart, not on every configuration switch.
          restartIfChanged = false;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # Idempotent: an existing namespace/interface is kept, so re-running
            # never strands confined services in an orphaned namespace.
            ExecStart = pkgs.writeShellScript "proton-vpn-netns-up" ''
              set -eu
              [ -e ${nsPath} ] || ip netns add ${ns}
              ip -n ${ns} link set lo up
              ip netns exec ${ns} sysctl -qw net.ipv6.conf.all.disable_ipv6=1
              if ! ip -n ${ns} link show ${ifname} >/dev/null 2>&1; then
                ip link delete ${ifname} 2>/dev/null || true
                # Created in the host namespace so its UDP socket uses the host's
                # uplink, then moved: only the decrypted side lives in the namespace.
                ip link add ${ifname} type wireguard
                ip link set ${ifname} netns ${ns}
              fi
              ip -n ${ns} address replace ${cfg.address} dev ${ifname}
              ip -n ${ns} link set ${ifname} mtu ${toString cfg.mtu} up
              # With no peer configured yet, this route is a black hole: confined
              # services can't reach anything until the tunnel is up.
              ip -n ${ns} route replace default dev ${ifname}
            '';
            ExecStop = "${pkgs.iproute2}/bin/ip netns delete ${ns}";
          };
        };

        proton-vpn-tunnel = {
          description = "Configure the Proton VPN WireGuard tunnel";
          wantedBy = [ "multi-user.target" ];
          requires = [ "proton-vpn-netns.service" ];
          wants = [ "network-online.target" ];
          after = [
            "proton-vpn-netns.service"
            "network-online.target"
          ];
          path = [
            pkgs.iproute2
            pkgs.wireguard-tools
            pkgs.jq
          ];
          startLimitIntervalSec = 0;
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "proton-vpn-netns";
            StateDirectoryMode = "0700";
            RuntimeDirectory = "proton-vpn-netns";
            RuntimeDirectoryMode = "0700";
            RuntimeDirectoryPreserve = true;
            # Transient failures (no network yet, API hiccup) retry quickly. Exit 2
            # means the sign-in itself was refused; retrying every minute could get
            # the account locked, so leave that to the next timer run.
            Restart = "on-failure";
            RestartSec = 60;
            RestartPreventExitStatus = 2;
            ExecStart = pkgs.writeShellScript "proton-vpn-tunnel" ''
              set -eu
              prefer=$(jq -r '.server // empty' ${stateDir}/server.json 2>/dev/null || true)
              ${lib.getExe cfg.package} ${confgenArgs} ''${prefer:+--prefer "$prefer"}
              ip netns exec ${ns} wg setconf ${ifname} ${runDir}/wg.conf
            '';
          };
        };

        proton-vpn-watchdog = {
          description = "Switch Proton VPN servers when the tunnel stops handshaking";
          requires = [ "proton-vpn-netns.service" ];
          after = [ "proton-vpn-netns.service" ];
          path = [
            pkgs.iproute2
            pkgs.wireguard-tools
            pkgs.jq
            pkgs.gawk
            pkgs.coreutils
            config.systemd.package
          ];
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "proton-vpn-netns";
            StateDirectoryMode = "0700";
            ExecStart = pkgs.writeShellScript "proton-vpn-watchdog" ''
              set -u
              now=$(date +%s)
              handshake=$(ip netns exec ${ns} wg show ${ifname} latest-handshakes 2>/dev/null | awk 'NR==1 {print $2}')
              handshake=''${handshake:-0}

              if [ "$handshake" -gt 0 ] && [ $((now - handshake)) -lt ${toString cfg.handshakeTimeout} ]; then
                if [ -f ${stateDir}/down-since ]; then
                  echo "Tunnel is back up after $((now - $(cat ${stateDir}/down-since)))s"
                  rm -f ${stateDir}/down-since
                fi
                exit 0
              fi

              [ -f ${stateDir}/down-since ] || echo "$now" > ${stateDir}/down-since
              down=$((now - $(cat ${stateDir}/down-since)))

              # Only judge a server once a config has been loaded and has had a full
              # timeout to handshake. Before any config exists, getting one is
              # proton-vpn-tunnel's job (including its back-off when the sign-in
              # is refused), so don't poke it from here.
              tunnel_state=$(systemctl show -p ActiveState --value proton-vpn-tunnel.service)
              if [ -f ${runDir}/wg.conf ] \
                && [ $((now - $(stat -c %Y ${runDir}/wg.conf))) -ge ${toString cfg.handshakeTimeout} ] \
                && [ "$tunnel_state" != activating ] && [ "$tunnel_state" != active ]; then
                server=$(jq -r '.server // empty' ${stateDir}/server.json 2>/dev/null || true)
                entry=$(jq -r '.entry_ip // empty' ${stateDir}/server.json 2>/dev/null || true)
                if [ "$handshake" -gt 0 ]; then age="for $((now - handshake))s"; else age="at all"; fi
                echo "No handshake $age on ''${server:-unknown server}; switching servers"
                # Mark both the name and the entry IP: several servers can share one IP.
                for bad in $server $entry; do echo "$bad $now" >> ${stateDir}/bad-servers; done
                # Keep the list short; the generator ignores entries older than a day anyway.
                awk -v cutoff=$((now - 86400)) '$2 >= cutoff' ${stateDir}/bad-servers > ${stateDir}/bad-servers.new \
                  && mv ${stateDir}/bad-servers.new ${stateDir}/bad-servers
                rm -f ${stateDir}/server.json
                systemctl start --no-block proton-vpn-tunnel.service
              fi

              if [ "$down" -ge ${toString cfg.alertAfter} ]; then
                echo "Proton VPN tunnel has been down for ''${down}s"
                exit 1
              fi
            '';
          };
        };
      }

      (lib.genAttrs cfg.confinedServices (_: confinement))

      (lib.listToAttrs (
        map (
          port:
          lib.nameValuePair "proton-vpn-netns-proxy-${toString port}" {
            description = "Proxy host port ${toString port} into the Proton VPN namespace";
            requires = [
              "proton-vpn-netns.service"
              "proton-vpn-netns-proxy-${toString port}.socket"
            ];
            after = [
              "proton-vpn-netns.service"
              "proton-vpn-netns-proxy-${toString port}.socket"
            ];
            partOf = [ "proton-vpn-netns.service" ];
            serviceConfig = {
              ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd 127.0.0.1:${toString port}";
              NetworkNamespacePath = nsPath;
              DynamicUser = true;
              PrivateTmp = true;
            };
          }
        ) cfg.forwardPorts
      ))

      (mkIf cfg.portForwarding.enable {
        proton-vpn-portforward = {
          description = "Keep a Proton VPN NAT-PMP port forward open";
          wantedBy = [ "multi-user.target" ];
          requires = [ "proton-vpn-netns.service" ];
          after = [
            "proton-vpn-netns.service"
            "proton-vpn-tunnel.service"
          ];
          # Restart with the confined services so the hook re-applies the port
          # as soon as they come back (they may reset it on start).
          partOf = [ "proton-vpn-netns.service" ] ++ map (s: "${s}.service") cfg.confinedServices;
          path = [
            pkgs.libnatpmp
            pkgs.gnugrep
            pkgs.coreutils
          ]
          ++ cfg.portForwarding.hookPath;
          serviceConfig = {
            NetworkNamespacePath = nsPath;
            RuntimeDirectory = "proton-vpn-netns";
            RuntimeDirectoryMode = "0700";
            RuntimeDirectoryPreserve = true;
            Restart = "always";
            RestartSec = 10;
            ExecStart = pkgs.writeShellScript "proton-vpn-portforward" ''
              set -u
              applied=""  # port the hook last applied successfully
              pending=""  # port the running hook is applying
              hook_pid=""
              rounds=0
              while true; do
                # The hook runs in the background: a slow service (e.g. one still
                # loading at startup) must never hold up renewing the mapping,
                # which expires after 60s.
                if [ -n "$hook_pid" ] && ! kill -0 "$hook_pid" 2>/dev/null; then
                  if wait "$hook_pid"; then
                    [ "$pending" = "$applied" ] || echo "Forwarded port is $pending"
                    applied="$pending"
                  else
                    echo "Port hook failed for $pending; will retry"
                    applied=""
                  fi
                  hook_pid=""
                fi

                # Proton expects private port 0 and hands back the public port to listen on.
                if out=$(natpmpc -g ${cfg.dns} -a 1 0 udp 60 && natpmpc -g ${cfg.dns} -a 1 0 tcp 60); then
                  port=$(echo "$out" | grep -oP 'Mapped public port \K[0-9]+' | tail -1)
                  if [ -n "$port" ]; then
                    echo "$port" > ${runDir}/forwarded-port
                    # Also re-apply every ~30 minutes, in case the service reset it.
                    if [ -z "$hook_pid" ] && { [ "$port" != "$applied" ] || [ $((rounds % 40)) -eq 0 ]; }; then
                      pending="$port"
                      PORT="$port" timeout 300 ${pkgs.writeShellScript "proton-vpn-portforward-hook" cfg.portForwarding.hook} &
                      hook_pid=$!
                    fi
                  fi
                else
                  echo "NAT-PMP request failed (tunnel down?)"
                  applied=""
                fi
                rounds=$((rounds + 1))
                sleep 45
              done
            '';
          };
        };
      })
    ];

    systemd.sockets = lib.listToAttrs (
      map (
        port:
        lib.nameValuePair "proton-vpn-netns-proxy-${toString port}" {
          description = "Host port ${toString port} for a Proton VPN-confined service";
          wantedBy = [ "sockets.target" ];
          listenStreams = [ (toString port) ];
        }
      ) cfg.forwardPorts
    );

    systemd.timers = {
      proton-vpn-tunnel = {
        description = "Renew the Proton VPN WireGuard certificate";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = cfg.refreshInterval;
          OnUnitActiveSec = cfg.refreshInterval;
          RandomizedDelaySec = "10m";
        };
      };
      proton-vpn-watchdog = {
        description = "Check the Proton VPN tunnel every minute";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "3min";
          OnUnitActiveSec = "1min";
          AccuracySec = "10s";
        };
      };
    };
  };
}
