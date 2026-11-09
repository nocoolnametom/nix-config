###############################################################################
#
#  Monline - arion container with Kanidm OIDC
#
#  Monline is a subscription monitoring service. Authentication is handled
#  directly by Monline's built-in OIDC provider integration (no oauth2-proxy).
#  The Kanidm client is configured in ../kanidm.nix.
#
#  Secrets (nix-secrets): homelab/kanidm/oidc/monline/client-secret
#
###############################################################################

{
  config,
  configVars,
  inputs,
  lib,
  ...
}:
let
  cfg = config.services.monline;
    uid = "1000";
    gid = "1000";
in
{
  imports = [ inputs.arion.nixosModules.arion ];

  options.services.monline = {
    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/monline";
      description = "Data directory for Monline.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = configVars.networking.ports.tcp.monline;
      description = "Host port the web UI is published on.";
    };
  };

  config = {
    sops.templates."monline.env".content = ''
      MONLINE_OIDC_CLIENT_SECRET=${config.sops.placeholder."homelab/kanidm/oidc/monline/client-secret"}
    '';

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 ${uid} ${gid} -"
    ];

    virtualisation.arion.backend = "docker";
    services.arion-container-cleanup.projects.monline.containers = [
      "arion-monline"
    ];

    virtualisation.arion.projects.monline.settings.services.monline = {
      service = {
        image = "ghcr.io/caglaryalcin/monline:latest";
        container_name = "arion-monline";
        labels."org.nix-config.managed-by" = "arion: change it in nix-config, not here";
        ports = [ "${toString cfg.port}:3000" ];
        environment = {
          MONLINE_HOST = "0.0.0.0";
          MONLINE_PORT = "3000";
          MONLINE_DATA_DIR = "/data";
          TZ = "America/New_York";
        };
        env_file = [ config.sops.templates."monline.env".path ];
        volumes = [
          "${cfg.stateDir}:/data"
        ];
        restart = "unless-stopped";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}