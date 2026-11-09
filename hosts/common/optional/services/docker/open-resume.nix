###############################################################################
#
#  Open Resume - arion container with oauth2-proxy auth
#
#  Open Resume is a resume builder. Authentication is handled by the
#  oauth2-proxy instance on estel (see ../oauth2-proxy.nix), which sets
#  the X-Forwarded-Preferred-Username header. Open Resume itself has no
#  built-in auth.
#
#  No persistent data directory is needed - resumes are stored in the
#  browser's local storage.
#
#  Secrets (nix-secrets): homelab/kanidm/oauth2/open-resume/client-secret
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
  cfg = config.services.open-resume;
  uid = 1000;
  gid = 1000;
in
{
  imports = [ inputs.arion.nixosModules.arion ];

  options.services.open-resume = {
    port = lib.mkOption {
      type = lib.types.port;
      default = configVars.networking.ports.tcp.open-resume;
      description = "Host port the web UI is published on.";
    };
  };

  config = {
    virtualisation.arion.backend = "docker";
    services.arion-container-cleanup.projects.open-resume.containers = [
      "arion-open-resume"
    ];

    virtualisation.arion.projects.open-resume.settings.services.open-resume = {
      service = {
        image = "peppershade/open-resume:latest";
        container_name = "arion-open-resume";
        labels."org.nix-config.managed-by" = "arion: change it in nix-config, not here";
        ports = [ "${toString cfg.port}:3000" ];
        restart = "unless-stopped";
        user = "${toString uid}:${toString gid}";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}