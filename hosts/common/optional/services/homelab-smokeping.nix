# Smokeping: long-running latency and packet-loss graphs for LAN and WAN targets.
#
# Wraps the nixpkgs services.smokeping module so a host only lists targets. The point
# is to see WHICH targets lose packets TOGETHER: one device alone points at that
# device, everything behind one mesh node points at that node's backhaul, every
# wireless target at once points at the main hub's radio, and wired plus WAN loss
# means it was never Wi-Fi.
#
# Web UI: plain HTTP on cfg.port on every interface, LAN only. Which web server serves
# it depends on the host:
# - Caddy host (services.caddy.enable): Caddy serves the CGI through its own fcgiwrap
#   socket and the upstream module's nginx is left OFF. Enabling nginx on a Caddy host
#   is not harmless: homelab-status-page.nix treats "nginx is enabled" as "this host
#   uses nginx", moves its vhost onto nginx on ports 80/443 and reassigns the TLS
#   certificate ownership, which took Caddy down on estel on 2026-11-06.
# - Otherwise: the upstream module's nginx vhost, moved off port 80 onto cfg.port.
# The host says which with `webServer`. It cannot be derived from services.caddy.enable:
# homelab-status-page.nix sets caddy.enable from nginx.enable, and nginx.enable would
# depend on this choice, which is an infinite recursion.
#
# Namespaced "homelab-" like the Beszel modules so it cannot clash with the upstream
# option set it configures. Changing `step` or the RRA lines after data exists requires
# deleting /var/lib/smokeping/data, so pick them once.
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.homelab-smokeping;
  useCaddy = cfg.webServer == "caddy";
  smokepingHome = "/var/lib/smokeping"; # fixed by the upstream module
  smokepingUser = config.services.smokeping.user;

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

    webServer = lib.mkOption {
      type = lib.types.enum [
        "nginx"
        "caddy"
      ];
      default = "nginx";
      description = ''
        Which web server serves the UI. Use "caddy" on hosts where Caddy is the reverse
        proxy (estel); enabling nginx there breaks homelab-status-page.nix (see header).
      '';
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

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.smokeping = {
          enable = true;
          # The upstream default is config.networking.fqdn, which throws when no domain is set.
          hostName = config.networking.hostName;
          # The CGI is installed as smokeping.fcgi; generated links should point there.
          cgiUrl = "http://${config.networking.hostName}:${toString cfg.port}/smokeping.fcgi";
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

        networking.firewall.allowedTCPPorts = lib.mkIf config.networking.firewall.enable [ cfg.port ];
      }

      # Caddy host: serve the CGI ourselves, keep nginx off (see header).
      (lib.mkIf useCaddy {
        services.smokeping.webService = false;

        services.fcgiwrap.instances.smokeping = {
          process.user = smokepingUser;
          process.group = smokepingUser;
          socket.user = config.services.caddy.user;
          socket.group = config.services.caddy.group;
        };

        # The upstream module makes the cache and data directories 0750 smokeping:smokeping;
        # Caddy serves the graph images out of the cache directly.
        users.users.${config.services.caddy.user}.extraGroups = [ smokepingUser ];

        # A port-only site address means plain HTTP, no automatic TLS.
        services.caddy.virtualHosts.":${toString cfg.port}" = {
          extraConfig = ''
            root * ${smokepingHome}
            # / and the nginx-style .cgi name both land on the CGI.
            rewrite / /smokeping.fcgi
            uri replace /smokeping.cgi /smokeping.fcgi
            @cgi path /smokeping.fcgi /smokeping.fcgi/*
            reverse_proxy @cgi unix/${config.services.fcgiwrap.instances.smokeping.socket.address} {
              transport fastcgi {
                root ${smokepingHome}
                split .fcgi
                env DOCUMENT_ROOT ${smokepingHome}
              }
            }
            # css/, js/ and cache/ (graph images) are plain files.
            file_server
          '';
        };
      })

      # nginx host: the upstream vhost would otherwise take port 80.
      (lib.mkIf (!useCaddy) {
        # null: nginx's server_name falls back to the vhost name and answers on any address.
        services.smokeping.host = null;
        services.nginx.virtualHosts.smokeping.listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
          }
        ];
      })
    ]
  );
}
