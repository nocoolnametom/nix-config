{
  pkgs,
  lib,
  config,
  ...
}:

let
  # Create a wrapper script that waits for sops before running activation
  # This avoids infinite recursion by not referencing config.system.build.toplevel
  activationWrapper = pkgs.writeShellScript "activate-system-wrapper" ''
    set -e
    set -o pipefail

    # Wait for /nix/store to be available
    /bin/wait4path /nix/store

    # Wait for sops-install-secrets to complete
    echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - Waiting for sops-install-secrets to complete..." >&2
    max_wait=30
    waited=0
    while [ ! -L /run/secrets ] && [ $waited -lt $max_wait ]; do
      sleep 1
      waited=$((waited + 1))
    done

    if [ ! -L /run/secrets ]; then
      echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - WARNING: sops-install-secrets did not complete within ''${max_wait}s" >&2
      echo "Secrets may not be available, continuing anyway" >&2
    else
      echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - sops-install-secrets completed, proceeding with activation" >&2
    fi

    # Read the current system configuration and run its activation script
    systemConfig=$(cat /nix/var/nix/profiles/system/systemConfig)
    echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - Running activation from $systemConfig" >&2

    # When running at boot via launchd (not in Aqua), the activation may fail due to
    # app management permissions. The activation exits before creating /run/current-system,
    # so we need to handle this gracefully and ensure the symlink gets created.
    # Temporarily disable exit-on-error to capture the exit code
    set +e
    "$systemConfig/activate"
    exit_code=$?
    set -e

    if [ $exit_code -eq 0 ]; then
      echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - Activation completed successfully" >&2
    elif [ $exit_code -eq 1 ]; then
      echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - WARNING: Activation failed with exit code 1 (likely app management permissions)" >&2
      echo "This is expected when running at boot outside of a graphical session." >&2

      # The activation script creates /run/current-system at the end, but exits early on error.
      # We need to manually create this symlink so the system environment is available.
      if [ ! -L /run/current-system ]; then
        echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - Creating /run/current-system symlink manually" >&2
        ln -sfn "$(readlink -f "$systemConfig")" /run/current-system

        # Also create the GC root
        if [ -d /nix/var/nix/gcroots ]; then
          ln -sfn /run/current-system /nix/var/nix/gcroots/current-system
        fi
      fi

      # Exit successfully so launchd doesn't keep retrying
      exit 0
    else
      echo "$(date -u '+%Y-%m-%d %H:%M:%S UTC') - ERROR: Activation failed with exit code $exit_code" >&2
      exit $exit_code
    fi
  '';
in
{
  # Ensure activation runs with proper dependencies at boot
  # This prevents multiple race conditions:
  #
  # Issue 1 (nix-store mounting): The activation wrapper is in /nix/store, but /nix
  # takes ~4s to mount at boot. If launchd tries to exec the wrapper before /nix is
  # available, it fails with exit code 126 and /run/current-system never gets created.
  #
  # Issue 2 (sops timing): Both org.nixos.activate-system and org.nixos.sops-install-secrets
  # run concurrently with RunAtLoad=true. If activation runs before sops completes,
  # any activation scripts that depend on secrets will fail.
  #
  # Solution:
  # 1. Use KeepAlive.PathState to ensure /nix/store exists before exec'ing the wrapper
  # 2. Wrapper script waits for /run/secrets (created by sops) before proceeding

  # Override the activate-system LaunchDaemon to use our wrapper
  launchd.daemons.activate-system = {
    serviceConfig = {
      ProgramArguments = lib.mkForce [
        "/bin/sh"
        "-c"
        "exec ${activationWrapper}"
      ];
      RunAtLoad = lib.mkForce true;
      StandardOutPath = lib.mkDefault "/var/log/activate-system.log";
      StandardErrorPath = lib.mkDefault "/var/log/activate-system.log";

      # Ensure /nix/store is mounted before trying to run the wrapper
      # Without this, launchd tries to exec the wrapper before /nix is available,
      # causing exit code 126 ("Command invoked cannot execute")
      KeepAlive = lib.mkForce {
        PathState."/nix/store" = true;
      };
    };
  };

  # Add logging to sops for debugging
  launchd.daemons.sops-install-secrets = lib.mkIf (config.sops.secrets != { }) {
    serviceConfig = {
      StandardOutPath = "/var/log/sops-install-secrets.log";
      StandardErrorPath = "/var/log/sops-install-secrets.log";
    };
  };
}
