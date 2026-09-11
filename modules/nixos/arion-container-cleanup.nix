{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.arion-container-cleanup;

  cleanupScript =
    project: projectCfg:
    pkgs.writeShellScript "arion-${project}-cleanup" ''
      set -uo pipefail

      docker="${projectCfg.dockerPackage}/bin/docker"
      sleep="${pkgs.coreutils}/bin/sleep"

      # Arion's generated unit is only ordered After=sockets.target, so on boot
      # this can run before dockerd is answering on its socket.
      waited=0
      until "$docker" info >/dev/null 2>&1; do
        if [ "$waited" -ge ${toString projectCfg.daemonTimeout} ]; then
          echo "docker daemon still unreachable after ${toString projectCfg.daemonTimeout}s" >&2
          exit 1
        fi
        "$sleep" 1
        waited=$((waited + 1))
      done

      for name in ${lib.escapeShellArgs projectCfg.containers}; do
        if ! "$docker" container inspect "$name" >/dev/null 2>&1; then
          continue
        fi

        echo "removing leftover container $name"
        "$docker" rm -f "$name" >/dev/null 2>&1 || true

        # `docker rm -f` returns once removal is *queued*, not once it is done.
        # While the daemon finishes tearing the container down it keeps holding
        # the name, so the immediately following `arion up` dies with
        #   Conflict. The container name "/$name" is already in use by container ...
        # Wait for the name to actually be released before handing off to arion.
        waited=0
        while "$docker" container inspect "$name" >/dev/null 2>&1; do
          if [ "$waited" -ge ${toString projectCfg.removalTimeout} ]; then
            echo "container $name still present ${toString projectCfg.removalTimeout}s after removal; giving up" >&2
            exit 1
          fi
          "$sleep" 1
          waited=$((waited + 1))
        done

        echo "container $name removed"
      done
    '';
in
{
  options.services.arion-container-cleanup = {
    projects = lib.mkOption {
      default = { };
      description = ''
        Arion projects whose containers should be force-recreated on every
        start of their `arion-<project>.service` unit.

        Arion runs `arion up` attached in a `Type=simple` unit, so a stop that
        outruns `TimeoutStopSec` (or a crash mid-teardown) can leave the
        container behind. On the next start docker-compose then either reuses a
        container that is up but detached from its bridge network, or fails
        outright with a name conflict.

        For each entry this removes the named containers in an `ExecStartPre`,
        waits until the daemon has actually released the names, orders the unit
        after `docker.service`, and retries the unit on failure.
      '';
      example = lib.literalExpression ''
        {
          invokeai = { };
          comfyui-docker.containers = [ "comfyui-docker" ];
        }
      '';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              containers = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ name ];
                defaultText = lib.literalExpression "[ <project name> ]";
                description = ''
                  Container names to remove before starting the project. Defaults
                  to the project name, which matches the common case of a single
                  service whose `container_name` is the project name.
                '';
              };

              dockerPackage = lib.mkOption {
                type = lib.types.package;
                default = config.virtualisation.docker.package;
                defaultText = lib.literalExpression "config.virtualisation.docker.package";
                description = "Docker package providing the CLI used for cleanup.";
              };

              daemonTimeout = lib.mkOption {
                type = lib.types.int;
                default = 60;
                description = "Seconds to wait for the docker daemon to become reachable.";
              };

              removalTimeout = lib.mkOption {
                type = lib.types.int;
                default = 60;
                description = "Seconds to wait for a container name to be released after removal.";
              };

              restartSec = lib.mkOption {
                type = lib.types.str;
                default = "15s";
                description = "Delay before systemd retries the arion unit after a failure.";
              };

              startLimitBurst = lib.mkOption {
                type = lib.types.int;
                default = 3;
                description = ''
                  Failed starts allowed within `startLimitIntervalSec` before
                  systemd stops retrying. Bounds the retry loop for failures
                  that a retry cannot fix - a published port held by another
                  process, say - instead of failing (and alerting) every
                  `restartSec` indefinitely.
                '';
              };

              startLimitIntervalSec = lib.mkOption {
                type = lib.types.str;
                default = "5min";
                description = "Window over which `startLimitBurst` is counted.";
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkIf (cfg.projects != { }) {
    systemd.services = lib.mapAttrs' (
      project: projectCfg:
      lib.nameValuePair "arion-${project}" {
        after = [ "docker.service" ];
        wants = [ "docker.service" ];
        unitConfig = {
          StartLimitBurst = projectCfg.startLimitBurst;
          StartLimitIntervalSec = projectCfg.startLimitIntervalSec;
        };
        serviceConfig = {
          ExecStartPre = [ "${cleanupScript project projectCfg}" ];
          Restart = "on-failure";
          RestartSec = projectCfg.restartSec;
        };
      }
    ) cfg.projects;
  };
}
