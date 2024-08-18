# This is copied wholesale from: https://github.com/davidtwco/veritas/blob/d75d3e07c005adaa308f1cacdc6b5270fb389df7/nixos/modules/per-user-vpn.nix
{
  config,
  lib,
  pkgs,
  ...
}:

# This module defines the `services.per-user-vpn` options for setting up an OpenVPN
# client connection that forces certain system users' traffic over it.

with lib.attrsets;
with lib.lists;
with lib.options;
with lib.types;
let
  cfg = config.services.per-user-vpn;
in
{
  options.services.per-user-vpn = {
    enable = mkEnableOption "Enable per-user-vpn configurations";

    servers = mkOption {
      default = { };
      description = "Options for each per-user-vpn configuration.";
      type = attrsOf (submodule {
        options = {
          certificate = mkOption {
            description = "Path to file containing certificate of VPN.";
            type = str;
          };

          tls-file = mkOption {
            default = null;
            description = "Path to file containing certificate of VPN.";
            type = str;
          };

          credentialsFile = mkOption {
            description = "Path to file containing username and password (first username then password on their own lines) to authenticate with VPN.";
            type = str;
          };

          dns = {
            ipv4 = {
              primary = mkOption {
                default = "1.1.1.1";
                description = "Primary IPv4 DNS server to use for VPN traffic.";
                type = str;
              };

              secondary = mkOption {
                default = "1.0.0.1";
                description = "Secondary IPv4 DNS server to use for VPN traffic.";
                type = str;
              };
            };

            ipv6 = {
              primary = mkOption {
                default = "2606:4700:4700::1111";
                description = "Primary IPv6 DNS server to use for VPN traffic.";
                type = str;
              };

              secondary = mkOption {
                default = "2606:4700:4700::1001";
                description = "Secondary IPv6 DNS server to use for VPN traffic.";
                type = str;
              };
            };
          };

          localNetworks = {
            ipv4 = mkOption {
              default = [
                "10.0.0.0/8"
                "172.16.0.0/12"
                "192.168.0.0/16"
              ];
              description = ''
                List of IPv4 addresses in the local network. Used to force local DNS over VPN.
              '';
              type = listOf str;
            };

            ipv6 = mkOption {
              default = [ "fd00::/8" ];
              description = ''
                List of IPv6 addresses in the local network. Used to force local DNS over VPN.
              '';
              type = listOf str;
            };
          };

          mark = mkOption {
            description = ''
              Arbitrary string of the form '0xN' that is used to mark packets in firewall rules.
              Must not overlap with other per-user-vpn configurations.
            '';
            type = str;
          };

          protocol = mkOption {
            default = "udp";
            description = "Protocol to use when connecting to OpenVPN server.";
            type = enum [
              "udp"
              "tcp"
            ];
          };

          remotes = mkOption {
            description = "List of OpenVPN remote servers that will be used.";
            type = listOf str;
          };

          routeTableId = mkOption {
            description = ''
              Id of routing table that will be defined to route traffic onto the VPN. This can be
              any arbitrary number, that doesn't already identify a routing table.
            '';
            type = int;
          };

          users = mkOption {
            description = "Names of users whose traffic will be forced onto the VPN.";
            type = listOf str;
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable (
    let
      mkFirewallRules =
        name: srv:
        let
          # Define chain names for the firewall.
          chains = {
            input = "${name}-vpn-input";
            output = "${name}-vpn-output";
            prerouting = "${name}-vpn-prerouting";
            postrouting = "${name}-vpn-postrouting";
          };

          # Concatenate networks for use in iptables rules.
          ipv4Networks = builtins.concatStringsSep "," srv.localNetworks.ipv4;
          ipv6Networks = builtins.concatStringsSep "," srv.localNetworks.ipv6;

          # Mark all relevant packets for a user.
          markPacketForUser =
            user:
            let
              inputs = [
                {
                  inherit user;
                  command = "iptables";
                  networks = ipv4Networks;
                }
                {
                  inherit user;
                  command = "ip6tables";
                  networks = ipv6Networks;
                }
              ];

              # Mark a DNS packet sent to a network for the user.
              markDnsPacketForUser =
                {
                  command,
                  networks,
                  user,
                }:
                ''
                  ${command} -t mangle -A ${chains.output} --dest "${networks}" -p udp --dport domain -m owner --uid-owner ${user} -j MARK --set-mark ${srv.mark}
                  ${command} -t mangle -A ${chains.output} --dest "${networks}" -p tcp --dport domain -m owner --uid-owner ${user} -j MARK --set-mark ${srv.mark}
                '';
            in
            ''
              # Mark all outgoing packets from the VPN user (these will be unmarked later). An
              # initial mark followed by an unmark is used because it isn't possible to check for
              # multiple destinations and negate that check (i.e. `! --dest W.X.Y.Z/F,A.B.C.D/G`
              # is disallowed) and if these checks were split up then all but one would always be
              # triggered.
              ip46tables -t mangle -A ${chains.output} ! -o lo -m owner --uid-owner ${user} -j MARK --set-mark ${srv.mark}

              # Unmark outgoing packets from the VPN user when being sent to a private network.
              # This means that hosts on the local network will still be able to browse to any web
              # services without being blocked.
              iptables -t mangle -A ${chains.output} --dest "${ipv4Networks}" -m owner --uid-owner ${user} -j MARK --xor-mark ${srv.mark}
              ip6tables -t mangle -A ${chains.output} --dest "${ipv6Networks}" -m owner --uid-owner ${user} -j MARK --xor-mark ${srv.mark}

              # Re-mark packets on the private network if they are DNS (forcing DNS to go through
              # the VPN).
              ${builtins.concatStringsSep "\n" (builtins.map markDnsPacketForUser inputs)}
            '';

          # Force DNS for the user to go over the VPN.
          forceDnsForUser =
            user:
            let
              inputs = [
                {
                  inherit user;
                  command = "iptables";
                  networks = ipv4Networks;
                  dns = srv.dns.ipv4;
                  protocol = "tcp";
                }
                {
                  inherit user;
                  command = "iptables";
                  networks = ipv4Networks;
                  dns = srv.dns.ipv4;
                  protocol = "udp";
                }
                {
                  inherit user;
                  command = "ip6tables";
                  networks = ipv6Networks;
                  dns = srv.dns.ipv6;
                  protocol = "tcp";
                }
                {
                  inherit user;
                  command = "ip6tables";
                  networks = ipv6Networks;
                  dns = srv.dns.ipv6;
                  protocol = "udp";
                }
              ];

              # Add to the nat table so that DNS requests to internal networks are sent to the
              # configured DNS server (and therefore over the VPN interface, when the packet passes
              # through the filter table).
              redirectDnsPacketForUser =
                {
                  command,
                  dns,
                  networks,
                  protocol,
                  user,
                }:
                ''
                  ${command} -t nat -A ${chains.output} --dest "${networks}" -p ${protocol} --dport domain -m owner --uid-owner ${user} -j DNAT --to-destination ${dns.primary}
                  ${command} -t nat -A ${chains.output} --dest "${networks}" -p ${protocol} --dport domain -m owner --uid-owner ${user} -j DNAT --to-destination ${dns.secondary}
                '';
            in
            builtins.concatStringsSep "\n" (builtins.map redirectDnsPacketForUser inputs);

          # Accept packets from the VPN user that are on the local interface or VPN interface.
          acceptAllLocalOrVpnInterface = user: ''
            # Accept all outgoing packets on `lo` and the VPN interface from the VPN user.
            ip46tables -t filter -A ${chains.output} -o lo -m owner --uid-owner ${user} -j ACCEPT
            ip46tables -t filter -A ${chains.output} -o tun-${name} -m owner --uid-owner ${user} -j ACCEPT
          '';
        in
        ''
          # Create the chains in the filter table.
          #
          # If we don't remove existing rules at the start of this section then there will be
          # duplicates. NixOS handles this by suggesting that rules be added to the `nixos-fw`
          # chain. However, `nixos-fw` is only referenced from `INPUT` on the `filter` table, and
          # thus isn't suitable for this (we need other tables and chains).
          #
          # Therefore, in this section, we create our own chains (and delete them if they already
          # exist) and insert a jump to them from the regular chains on all relevant tables.
          #
          # Invariant: These chains should all fall-through by default so that the regular NixOS
          # chains and rules can apply.
          for table in filter nat mangle; do
            # Delete any existing jumps to the VPN chains.
            ip46tables -t "$table" -D INPUT -j ${chains.input} 2> /dev/null || true
            ip46tables -t "$table" -D OUTPUT -j ${chains.output} 2> /dev/null || true

            for chain in ${chains.input} ${chains.output}; do
              # Flush the chain (ignoring errors if it doesn't exist).
              ip46tables -t "$table" -F "$chain" 2> /dev/null || true
              # Delete the chain (ignoring errors if it doesn't exist).
              ip46tables -t "$table" -X "$chain" 2> /dev/null || true
              # Create the chain.
              ip46tables -t "$table" -N "$chain"
            done

            # Add a jump to the VPN chains.
            ip46tables -t "$table" -A INPUT -j ${chains.input}
            ip46tables -t "$table" -A OUTPUT -j ${chains.output}
          done

          # Manually handle the prerouting/postrouting chain in the nat table - it doesn't fit the
          # above loop.
          ip46tables -t nat -D PREROUTING -j ${chains.prerouting} 2> /dev/null || true
          ip46tables -t nat -D POSTROUTING -j ${chains.postrouting} 2> /dev/null || true
          for chain in ${chains.prerouting} ${chains.postrouting}; do
            ip46tables -t nat -F "$chain" 2> /dev/null || true
            ip46tables -t nat -X "$chain" 2> /dev/null || true
            ip46tables -t nat -N "$chain"
          done
          ip46tables -t nat -A PREROUTING -j ${chains.prerouting}
          ip46tables -t nat -A POSTROUTING -j ${chains.postrouting}

          # Accept existing connections.
          ip46tables -t filter -A ${chains.input} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
          ip46tables -t filter -A ${chains.output} -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

          # Packets will go through the mangle table first..

          # Copy connection mark to the packet mark.
          ip46tables -t mangle -A ${chains.output} -j CONNMARK --restore-mark

          # Mark packets from the VPN user go to the VPN interface.
          ${builtins.concatStringsSep "\n" (builtins.map markPacketForUser srv.users)}

          # Copy packet mark to the connection mark.
          ip46tables -t mangle -A ${chains.output} -j CONNMARK --save-mark

          # ..and then the nat table..

          # Make any DNS from the VPN user go to the VPN provider's DNS.
          ${builtins.concatStringsSep "\n" (builtins.map forceDnsForUser srv.users)}

          # Masquerade all packets on the VPN interface.
          ip46tables -t nat -A ${chains.postrouting} -o tun-${name} -j MASQUERADE

          # ..and finally the filter table.

          # Accept everything incoming on the VPN interface.
          ip46tables -t filter -A ${chains.input} -i tun-${name} -j ACCEPT

          # Accept packets from the VPN user that are on the local interface or VPN interface.
          ${builtins.concatStringsSep "\n" (builtins.map acceptAllLocalOrVpnInterface srv.users)}
        '';

      mkRoutingScript =
        srvName: srv:
        let
          name = "${srvName}-vpn-routes";
          dir = pkgs.writeScriptBin name ''
            #! ${pkgs.runtimeShell} -e
            # Flush routes currently in the table.
            HAS_TABLE="$(${pkgs.iproute}/bin/ip route show table all | ${pkgs.gnugrep}/bin/grep "table" | ${pkgs.gnused}/bin/sed 's/.*\(table.*\)/\1/g' | ${pkgs.gawk}/bin/awk '{ print $2 }' | ${pkgs.coreutils}/bin/sort -u | ${pkgs.gnugrep}/bin/grep -c "${srvName}" || true)"
            if [[ $HAS_TABLE == "1" ]]; then
              ${pkgs.iproute}/bin/ip route flush table ${builtins.toString srv.routeTableId}
            fi

            # Add a rule to the routing rules for marked packets. These rules are checked in
            # priority order (lowest first - see `ip rule list`) and if no routes within match,
            # then the next rule is checked. This rule will be the second rule (the first being
            # local packets) and will apply for the marked packets.
            HAS_RULE="$(${pkgs.iproute}/bin/ip rule list | ${pkgs.gnugrep}/bin/grep -c ${srv.mark} || true)"
            if [[ $HAS_RULE == "0" ]]; then
              ${pkgs.iproute}/bin/ip rule add from all fwmark ${srv.mark} lookup ${builtins.toString srv.routeTableId}
            fi

            HAS_VPN_INTERFACE="$(${pkgs.iproute}/bin/ip -o link show | ${pkgs.gawk}/bin/awk -F': ' '{print $2}' | ${pkgs.gnugrep}/bin/grep -c tun-${srvName} || true)"
            if [[ $HAS_VPN_INTERFACE == "1" ]]; then
              HAS_IP="$(${pkgs.iproute}/bin/ip addr show tun-${srvName} | ${pkgs.gnugrep}/bin/grep -cPo '(?<= inet )([0-9\.]+) ' || true)"
              if [[ $HAS_IP == "1" ]]; then
                VPN_IP="$(${pkgs.iproute}/bin/ip addr show tun-${srvName} | ${pkgs.gnugrep}/bin/grep -Po '(?<= inet )([0-9\.]+) ')"

                ${pkgs.iproute}/bin/ip route replace default via $VPN_IP table ${builtins.toString srv.routeTableId}
              fi
            fi

            ${pkgs.iproute}/bin/ip route append default via 127.0.0.1 dev lo table ${builtins.toString srv.routeTableId}

            ${pkgs.iproute}/bin/ip route flush cache
          '';
        in
        "${dir}/bin/${name}";

      mkOpenVpnConfig = name: srv: ''
        # Specify the type of the layer of the VPN connection.
        client
        dev tun-${name}
        dev-type tun

        # Specify the underlying protocol beyond the Internet.
        proto ${srv.protocol}

        # The destination hostname / IP address, and port number of
        # the target VPN Server.
        ${builtins.concatStringsSep "\n" (builtins.map (r: "remote ${r}") srv.remotes)}

        remote-random
        resolv-retry infinite
        nobind

        # The encryption and authentication algorithm.
        cipher AES-256-CBC
        tls-cipher TLS-DHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-CBC-SHA

        auth SHA512
        verb 3

        # Other parameters necessary to connect to the VPN Server.
        setenv CLIENT_CERT 0
        tun-mtu 1500
        tun-mtu-extra 32
        mssfix 1450
        persist-key
        persist-tun

        reneg-sec 0

        remote-cert-tls server
        fast-io
        script-security 2

        # The certificate file of the destination VPN Server.
        ca ${srv.certificate}

        key-direction 1

        # The tls auth file for the server.
        tls-auth ${srv.tls-file}

        # Disable the client from sending all traffic over the VPN by default.
        pull-filter ignore redirect-gateway
      '';

      mkOpenVpnUpScript = name: srv: ''
        # Workaround: OpenVPN will run `ip addr add` to assign an IP to the interface. However,
        # sometimes this won't do anything. In order to make sure that we always get an IP, sleep
        # and then run the command again.
        HAS_IP="$(${pkgs.iproute}/bin/ip addr show tun-${name} | ${pkgs.gnugrep}/bin/grep -c '$4' || true)"
        if [[ $HAS_IP == "0" ]]; then
          sleep 5
          ${pkgs.iproute}/bin/ip addr add dev tun-${name} local $4 peer $5
        fi

        # Routing script is invoked here and at startup. When run from the OpenVPN up script, it
        # should create a new route in the VPN routing table to the newly started VPN.
        ${mkRoutingScript name srv}
      '';
    in
    {
      # Set kernel reverse path filtering to loose.
      boot.kernel.sysctl = {
        "net.ipv4.conf.all.rp_filter" = 2;
        "net.ipv4.conf.default.rp_filter" = 2;
      } // mapAttrs' (name: _: nameValuePair "net.ipv4.conf.${name}.rp_filter" 2) cfg.servers;

      # Set NixOS' firewall reverse path filtering to loose.
      networking.firewall.checkReversePath = "loose";

      # Enable ip routing and add route tables for each server.
      networking.iproute2 = {
        enable = true;
        rttablesExtraConfig = builtins.concatStringsSep "\n" (
          mapAttrsToList (name: srv: "${builtins.toString srv.routeTableId} ${name}") cfg.servers
        );
      };

      # Change system-wide nameservers. Necessary when the default DNS server for the services is
      # running locally and requests might be leaked when systemd-resolved makes the upstream
      # requests.
      networking.nameservers = flatten (
        mapAttrsToList (
          _: srv: with srv.dns; [
            ipv4.primary
            ipv4.secondary
            ipv6.primary
            ipv6.secondary
          ]
        ) cfg.servers
      );

      # Use systemd-resolved's global DNS servers for all domains, not the per-link DNS servers
      # (unless their search domains are specifically matched).
      services.resolved.domains = [ "~." ];

      # Create a service that runs on system start, so that the rule to `/dev/null` all marked
      # packets always applies. The same script will be invoked when OpenVPN starts to add a new
      # route that will go through the VPN.
      systemd.services = mapAttrs' (
        name: srv:
        nameValuePair "${name}-vpn-routes" {
          after = [ "systemd-modules-load.service" ];
          before = [ "network-pre.target" ];
          description = "Routing for ${name} VPN";
          path = [
            pkgs.iproute
            pkgs.gnugrep
            pkgs.gawk
          ];
          reloadIfChanged = false;
          serviceConfig = {
            "Type" = "oneshot";
            "RemainAfterExit" = true;
            "ExecStart" = "${mkRoutingScript name srv}";
          };
          unitConfig = {
            "ConditionCapability" = "CAP_NET_ADMIN";
            "DefaultDependencies" = false;
          };
          wantedBy = [ "sysinit.target" ];
          wants = [ "network-pre.target" ];
        }
      ) cfg.servers;

      # Set up VPN service.
      services.openvpn.servers = mapAttrs (name: srv: {
        autoStart = true;
        config =
          (mkOpenVpnConfig name srv)
          + ''
            auth-user-pass ${srv.credentialsFile}
          '';
        up = mkOpenVpnUpScript name srv;
        updateResolvConf = true;
      }) cfg.servers;

      # Create firewall rules to mark packets from targetted users.
      networking.firewall.extraCommands = builtins.concatStringsSep "\n" (
        mapAttrsToList mkFirewallRules cfg.servers
      );
    }
  );
}
