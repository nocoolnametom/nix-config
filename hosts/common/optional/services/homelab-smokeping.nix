# Smokeping: long-running latency and packet-loss graphs for LAN and WAN targets.
#
# Wraps the nixpkgs services.smokeping module so a host only lists targets. The point
# is to see WHICH targets lose packets TOGETHER: one device alone points at that
# device, everything behind one mesh node points at that node's backhaul, every
# wireless target at once points at the main hub's radio, and wired plus WAN loss
# means it was never Wi-Fi.
#
# The web UI is plain HTTP on cfg.port on every interface (LAN only; estel's firewall
# is off and the host is behind CGNAT). Namespaced "homelab-" like the Beszel modules
# so it cannot clash with the upstream option set it configures.
#
# Changing `step` or the RRA lines after data exists requires deleting
# /var/lib/smokeping/data, so pick them once.
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.homelab-smokeping;

  targetSection = targetName: target: ''
    ++ ${targetName}
    menu = ${target.title}
    title = ${target.title}
    host = ${target.address}
  '';

  groupSection = groupName: group: ''
    + ${groupName}
    menu = ${group.title}
    title = ${group.title}
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList targetSection group.targets)}
  '';
in
{
  options.services.homelab-smokeping = {
    enable = lib.mkEnableOption "smokeping latency grapher with a homelab target list";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8089;
      description = "Port the smokeping web UI listens on (all interfaces).";
    };

    groups = lib.mkOption {
      default = { };
      description = ''
        Targets to ping, grouped for the menu. Attribute names become smokeping section
        names, so keep them to letters, digits and underscores.
      '';
      example = lib.literalExpression ''
        {
          wifi = {
            title = "Wireless devices";
            targets.hue = { title = "Hue bridge"; address = "192.0.2.10"; };
          };
        }
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            title = lib.mkOption {
              type = lib.types.str;
              description = "Menu and page title for the group.";
            };
            targets = lib.mkOption {
              default = { };
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    title = lib.mkOption {
                      type = lib.types.str;
                      description = "Menu and graph title for the target.";
                    };
                    address = lib.mkOption {
                      type = lib.types.str;
                      description = "IP address or hostname to ping. Prefer IPs so DNS trouble cannot fake a loss.";
                    };
                  };
                }
              );
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    services.smokeping = {
      enable = true;
      # The upstream default is config.networking.fqdn, which throws when no domain is set.
      hostName = config.networking.hostName;
      cgiUrl = "http://${config.networking.hostName}:${toString cfg.port}/smokeping.cgi";
      # null: nginx's server_name falls back to the vhost name and answers on any address.
      host = null;
      # One-minute steps so a short Wi-Fi drop is visible instead of averaged into a 5-minute
      # bucket. 10 pings per step keeps fping's burst short. Retention per RRA line:
      # 3 days at 1 min, 30 days at 5 min, 1 year at 30 min.
      databaseConfig = ''
        step     = 60
        pings    = 10
        # consfn mrhb steps total
        AVERAGE  0.5   1  4320
        AVERAGE  0.5   5  8640
            MIN  0.5   5  8640
            MAX  0.5   5  8640
        AVERAGE  0.5  30 17520
            MIN  0.5  30 17520
            MAX  0.5  30 17520
      '';
      targetConfig = ''
        probe = FPing
        menu = Top
        title = Homelab network latency
        remark = Latency and packet loss as seen from ${config.networking.hostName} (wired). \
                 Compare which targets drop together to locate a Wi-Fi fault.

        ${lib.concatStringsSep "\n" (lib.mapAttrsToList groupSection cfg.groups)}
      '';
    };

    # The upstream module's vhost would otherwise take port 80, which Caddy owns on estel.
    services.nginx.virtualHosts.smokeping.listen = [
      {
        addr = "0.0.0.0";
        port = cfg.port;
      }
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf config.networking.firewall.enable [ cfg.port ];
  };
}
