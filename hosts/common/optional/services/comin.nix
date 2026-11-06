# comin: the host deploys this repo's `main` branch by itself.
#
# comin (github:nlewo/comin) polls the public nix-config repo, and when `main` moves it
# evaluates nixosConfigurations.<hostname>, builds it and switches. A branch named
# `testing-<hostname>` is applied with `nixos-rebuild test` instead (undone by a reboot).
#
# What this module decides for every host that imports it:
# - `system.autoUpgrade` is turned off. Two things must not both switch the system, and
#   auto-upgrade updated inputs without writing the lock back, which is the drift comin
#   replaces. bombadil keeps auto-upgrade and does not import this.
# - The nixpkgs downgrade guard is on, so a deploy of an older lock is refused.
# - Build or deploy failures send a Pushover message through the credentials already used
#   by systemd-failure-alert, once per commit and phase, with the commit and the error.
# - Builds are retried a few times, then given up until `main` moves again.
# - GitHub's SSH host key is trusted system-wide. comin fetches this repo over HTTPS, but
#   evaluating it as root fetches the private inputs (nix-secrets, my-sd-models) over
#   git+ssh with the root key that hosts/common/core/sops.nix installs, and root has no
#   persisted known_hosts on impermanence hosts.
#
# Credentials: none beyond what every host already has (root's GitHub deploy key via sops).
# Persist /var/lib/comin and /var/lib/nixpkgs-downgrade-guard on impermanence hosts.
{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.homelabComin;
  alertCfg = config.services.systemd-failure-alert;
  pushoverEnabled = alertCfg.enable && alertCfg.pushover.enable;

  # Runs after every build and every deployment. Quiet unless the phase failed.
  failureAlert = pkgs.writeShellScript "comin-failure-alert" ''
    set -u
    [ "''${COMIN_STATUS:-}" = "failed" ] || exit 0

    # One alert per commit per phase: comin retries failed builds and would otherwise
    # send the same message several times.
    markerDirectory=/var/lib/comin/alerts
    ${pkgs.coreutils}/bin/mkdir -p "$markerDirectory"
    marker="$markerDirectory/''${COMIN_PHASE:-unknown}-''${COMIN_GIT_SHA:-unknown}"
    [ -e "$marker" ] && exit 0

    hostName=$(${pkgs.hostname}/bin/hostname)
    shortSha=$(printf '%s' "''${COMIN_GIT_SHA:-}" | ${pkgs.coreutils}/bin/cut -c1-10)
    message="Commit $shortSha on ''${COMIN_GIT_REF:-?}: ''${COMIN_GIT_MSG:-}
    ''${COMIN_ERROR_MSG:-no error message}"
    # Pushover rejects messages over 1024 characters.
    message=$(printf '%s' "$message" | ${pkgs.coreutils}/bin/cut -c1-900)

    ${pkgs.curl}/bin/curl -s --fail \
      --form-string "token=$(${pkgs.coreutils}/bin/cat ${alertCfg.pushover.apiTokenFile})" \
      --form-string "user=$(${pkgs.coreutils}/bin/cat ${alertCfg.pushover.userKeyFile})" \
      --form-string "title=[$hostName] comin ''${COMIN_PHASE:-?} failed" \
      --form-string "message=$message" \
      --form-string "priority=${toString alertCfg.pushover.priority}" \
      https://api.pushover.net/1/messages.json \
      && ${pkgs.coreutils}/bin/touch "$marker"
  '';
in
{
  imports = [ inputs.comin.nixosModules.comin ];

  options.homelabComin = {
    repositoryUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/nocoolnametom/nix-config.git";
      description = "Git remote comin polls. The repo is public, so no credential is needed for this.";
    };

    pollPeriodSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 120;
      description = "How often comin fetches the remote.";
    };
  };

  config = {
    services.comin = {
      enable = true;
      remotes = [
        {
          name = "origin";
          url = cfg.repositoryUrl;
          branches.main.name = "main";
          # testing-<hostname> is applied with `test`, so a reboot undoes it. A testing
          # branch must not change flake.lock (database migrations are not undone).
          branches.testing.name = "testing-${config.networking.hostName}";
          poller.period = cfg.pollPeriodSeconds;
        }
      ];
      # A broken commit should not be rebuilt forever; three tries covers a flaky fetch.
      buildAttemptsLimit = 3;
      buildRetryTimer = 120;
      postBuildCommand = lib.mkIf pushoverEnabled failureAlert;
      postDeploymentCommand = lib.mkIf pushoverEnabled failureAlert;
    };

    # Set at normal priority on purpose: headless-server.nix enables auto-upgrade with
    # mkDefault, and a host that sets it to true explicitly should get a conflict error
    # rather than two deployers.
    system.autoUpgrade.enable = false;

    system.nixpkgsDowngradeGuard.enable = true;

    programs.ssh.knownHosts.github = {
      hostNames = [ "github.com" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };

    # comin restarts itself on failure, but if the unit ever stays down, say so.
    services.systemd-failure-alert.additional-services = lib.mkIf alertCfg.enable [ "comin" ];
  };
}
