{
  lib,
  pkgs,
  writeShellScriptBin,
  deploy-rs,
  inputs,
  ...
}:

let
  # Access nix-secrets data
  secrets = inputs.nix-secrets;
  
  # Extract machine information from nix-secrets
  localMachines = lib.mapAttrs (name: info: {
    inherit name;
    ip = info.ip;
    type = "local";
  }) secrets.networking.subnets;

  externalMachines = lib.mapAttrs (name: info: {
    inherit name;
    ip = info.ip;
    type = "external";
  }) secrets.networking.external;

  # Combine all machines
  allMachines = localMachines // externalMachines;

  # Generate machine connectivity tests
  generateConnectivityTest = name: info: ''
    echo "[Deploy] Testing connectivity to ${name} (${info.ip})..."
    if timeout 5 nc -z "${info.ip}" 22 2>/dev/null; then
        echo "[Deploy] ✓ ${name} is reachable"
        DEPLOY_TARGETS+=("${name}")
        MACHINE_IPS["${name}"]="${info.ip}"
    else
        echo "[Deploy] ✗ ${name} is not reachable, skipping"
    fi
  '';

  connectivityTests = lib.concatStringsSep "\n" (
    lib.mapAttrsToList generateConnectivityTest allMachines
  );

in writeShellScriptBin "deploy-all" ''
  set -e

  # Auto-deployment script using deploy-rs with dynamic machine discovery
  SCRIPT_DIR="$(cd "$(dirname "''${BASH_SOURCE[0]}")" && pwd)"
  FLAKE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

  echo "[Deploy] Starting auto-deployment from $FLAKE_DIR"
  cd "$FLAKE_DIR"

  # Update the flake inputs
  echo "[Deploy] Updating flake inputs..."
  ${pkgs.nix}/bin/nix flake update --accept-flake-config

  # Declare arrays for machine tracking
  declare -a DEPLOY_TARGETS
  declare -A MACHINE_IPS

  # Test connectivity to all known machines
  ${connectivityTests}

  # Deploy to reachable machines
  if [ ''${#DEPLOY_TARGETS[@]} -eq 0 ]; then
      echo "[Deploy] No machines are reachable, aborting deployment"
      exit 1
  fi

  echo "[Deploy] Deploying to: ''${DEPLOY_TARGETS[*]}"

  for target in "''${DEPLOY_TARGETS[@]}"; do
      echo "[Deploy] Deploying to $target (''${MACHINE_IPS[$target]})..."
      if ${deploy-rs}/bin/deploy --flake . ".$target" --skip-checks; then
          echo "[Deploy] ✓ Successfully deployed to $target"
      else
          echo "[Deploy] ✗ Failed to deploy to $target"
      fi
  done

  echo "[Deploy] Deployment process completed!"
''