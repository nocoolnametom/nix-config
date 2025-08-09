#!/usr/bin/env bash
set -e

# Dynamic deployment script that queries nix-secrets for machine information
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

echo "[Deploy] Starting dynamic auto-deployment from $FLAKE_DIR"
cd "$FLAKE_DIR"

# Function to get machine information from nix-secrets
get_machine_info() {
    nix eval --json --apply '
        inputs:
        let
          secrets = inputs.nix-secrets;
          local = builtins.mapAttrs (name: info: {
            inherit name;
            ip = info.ip;
            type = "local";
          }) secrets.networking.subnets;
          
          external = builtins.mapAttrs (name: info: {
            inherit name; 
            ip = info.ip;
            type = "external";
          }) secrets.networking.external;
          
          # Get list of nixosConfigurations to filter deployable machines
          nixosConfigs = builtins.attrNames inputs.self.nixosConfigurations;
          
          # Combine and filter to only deployable machines
          allMachines = local // external;
          deployable = builtins.listToAttrs (
            builtins.filter (m: builtins.elem m.name nixosConfigs) 
            (builtins.attrValues allMachines)
          );
        in
          deployable
    ' .#
}

# Update the flake inputs
echo "[Deploy] Updating flake inputs..."
nix flake update --accept-flake-config

# Get machine information dynamically
echo "[Deploy] Discovering machines from nix-secrets..."
MACHINES_JSON=$(get_machine_info)

# Parse JSON and test connectivity
declare -a DEPLOY_TARGETS
declare -A MACHINE_IPS
declare -A MACHINE_TYPES

while IFS= read -r machine_name; do
    machine_ip=$(echo "$MACHINES_JSON" | jq -r ".\"$machine_name\".ip")
    machine_type=$(echo "$MACHINES_JSON" | jq -r ".\"$machine_name\".type")
    
    echo "[Deploy] Testing connectivity to $machine_name ($machine_ip) [$machine_type]..."
    
    if timeout 5 nc -z "$machine_ip" 22 2>/dev/null; then
        echo "[Deploy] ✓ $machine_name is reachable"
        DEPLOY_TARGETS+=("$machine_name")
        MACHINE_IPS["$machine_name"]="$machine_ip"
        MACHINE_TYPES["$machine_name"]="$machine_type"
    else
        echo "[Deploy] ✗ $machine_name is not reachable, skipping"
    fi
done < <(echo "$MACHINES_JSON" | jq -r 'keys[]')

# Deploy to reachable machines
if [ ${#DEPLOY_TARGETS[@]} -eq 0 ]; then
    echo "[Deploy] No machines are reachable, aborting deployment"
    exit 1
fi

echo "[Deploy] Found ${#DEPLOY_TARGETS[@]} reachable machines: ${DEPLOY_TARGETS[*]}"

# Group deployments by type for better output
local_machines=()
external_machines=()

for target in "${DEPLOY_TARGETS[@]}"; do
    if [ "${MACHINE_TYPES[$target]}" = "local" ]; then
        local_machines+=("$target")
    else
        external_machines+=("$target")
    fi
done

# Deploy to local machines first (typically faster)
if [ ${#local_machines[@]} -gt 0 ]; then
    echo "[Deploy] Deploying to local machines: ${local_machines[*]}"
    for target in "${local_machines[@]}"; do
        echo "[Deploy] Deploying to $target (${MACHINE_IPS[$target]})..."
        if deploy --flake . ".$target" --skip-checks; then
            echo "[Deploy] ✓ Successfully deployed to $target"
        else
            echo "[Deploy] ✗ Failed to deploy to $target"
        fi
    done
fi

# Then deploy to external machines
if [ ${#external_machines[@]} -gt 0 ]; then
    echo "[Deploy] Deploying to external machines: ${external_machines[*]}"
    for target in "${external_machines[@]}"; do
        echo "[Deploy] Deploying to $target (${MACHINE_IPS[$target]})..."
        if deploy --flake . ".$target" --skip-checks; then
            echo "[Deploy] ✓ Successfully deployed to $target"
        else
            echo "[Deploy] ✗ Failed to deploy to $target"
        fi
    done
fi

echo "[Deploy] Deployment process completed!"
echo "[Deploy] Summary:"
echo "[Deploy]   Local machines: ${#local_machines[@]}"
echo "[Deploy]   External machines: ${#external_machines[@]}"
echo "[Deploy]   Total deployed: ${#DEPLOY_TARGETS[@]}"