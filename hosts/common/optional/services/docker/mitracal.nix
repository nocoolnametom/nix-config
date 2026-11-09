###############################################################################
#
#  Mitra Calendar - arion container with Kanidm OIDC
#
#  Mitra is a self-hosted calendar application. Authentication is handled
#  directly by Mitra's built-in OIDC provider integration (no oauth2-proxy).
#  The Kanidm client is configured in ../kanidm.nix with the custom issuer
#  URL https://sso.<domain>/oauth2/openid/mitracal.
#
#  Secrets (nix-secrets): homelab/kanidm/oidc/mitracal/client-secret,
#  homelab/mitracal/google-client-id, homelab/mitracal/google-client-secret
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
  cfg = config.services.mitracal;
    uid = "1000";
    gid = "1000";
in
{
  imports = [ inputs.arion.nixosModules.arion ];

  options.services.mitracal = {
    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/mitracal";
      description = "Data directory for Mitra calendar.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = configVars.networking.ports.tcp.mitracal;
      description = "Host port the web UI is published on.";
    };
  };

  config = {
    sops.secrets."homelab/mitracal/google-client-id" = { };
    sops.secrets."homelab/mitracal/google-client-secret" = { };
    sops.templates."mitracal.env".content = ''
      MITRA_OIDC_CLIENT_SECRET=${config.sops.placeholder."homelab/kanidm/oidc/mitracal/client-secret"}
      MITRA_GOOGLE_CLIENT_ID=${config.sops.placeholder."homelab/mitracal/google-client-id"}
      MITRA_GOOGLE_CLIENT_SECRET=${config.sops.placeholder."homelab/mitracal/google-client-secret"}
    '';

    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 ${uid} ${gid} -"
    ];

    virtualisation.arion.backend = "docker";
    services.arion-container-cleanup.projects.mitracal.containers = [
      "arion-mitracal"
    ];

    virtualisation.arion.projects.mitracal.settings.services.mitra = {
      service = {
        image = "ghcr.io/a11delavar/mitra:latest";
        container_name = "arion-mitracal";
        labels."org.nix-config.managed-by" = "arion: change it in nix-config, not here";
        ports = [ "${toString cfg.port}:3000" ];
        environment = {
          MITRA_OIDC_ISSUER = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/mitracal";
          MITRA_OIDC_CLIENT_ID = "mitracal";
          MITRA_URL = "https://${configVars.networking.subdomains.mitracal}.${configVars.homeDomain}";
        };
        env_file = [ config.sops.templates."mitracal.env".path ];
        volumes = [
          "${cfg.stateDir}:/app/data"
        ];
        restart = "unless-stopped";
        user = "${toString uid}:${toString gid}";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}