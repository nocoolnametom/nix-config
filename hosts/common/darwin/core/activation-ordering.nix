{ pkgs, lib, config, ... }:

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
    exec "$systemConfig/activate"
  '';
in
{
  # Ensure activation waits for sops-install-secrets to complete before running
  # This prevents race conditions where activation tries to run before secrets are available
  #
  # Issue: At boot, both org.nixos.activate-system and org.nixos.sops-install-secrets
  # run concurrently with RunAtLoad=true. If activation runs before sops completes,
  # any activation scripts that depend on secrets will fail.
  #
  # Solution: Create a wrapper script that waits for /run/secrets (created by sops)
  # before proceeding with activation. This ensures proper ordering without circular dependencies.

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
    };
  };

  # Add logging to sops for debugging
  launchd.daemons.sops-install-secrets = lib.mkIf (config.sops.secrets != {}) {
    serviceConfig = {
      StandardOutPath = "/var/log/sops-install-secrets.log";
      StandardErrorPath = "/var/log/sops-install-secrets.log";
    };
  };
}
