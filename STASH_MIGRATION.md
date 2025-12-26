# Stash Service Migration Guide

## Overview

This guide explains how to migrate from the custom `services.stashapp` module to the official nixpkgs `services.stash` module while preserving the VR helper functionality.

## What Was Changed

### New Files
1. **`modules/nixos/stash-vr-helper.nix`** - Extends nixpkgs stash service with VR helper support
2. **`hosts/common/optional/services/stash.nix`** - New configuration using nixpkgs service

### Modified Files
1. **`modules/nixos/default.nix`** - Registered the new stash-vr-helper module

### Unchanged Files
- **`modules/nixos/stashapp.nix`** - Original custom module (kept for reference)
- **`hosts/common/optional/services/stashapp.nix`** - Original configuration (kept for reference)

## Required Secrets Setup

You need to add **three secrets per machine** to your nix-secrets repository. These should be extracted from the existing `/var/lib/stashapp/.stash/config.yml` on each machine.

### Example: Machine named "durin"

From your existing `config.yml`, extract these values:

```yaml
# config.yml
password: $2a$04$nf30fc.k4EaQurK7qRsQQuo4sl9V/G3s1NzsqiMMZSSVfM7k.nUhq
jwt_secret_key: 09df1191df5809c93b9778e9f2c13b405dbd6d8ff426fbda11ccb7af0a2b072d
session_store_key: b0b0e06a0a70db2bbff13131e10a644d188e878c2ad6aff23f2a0de17ed57f15
```

Then add to your `secrets.yaml` in nix-secrets:

```yaml
# For machine "durin"
stash:
  durin:
    password: |
      $2a$04$nf30fc.k4EaQurK7qRsQQuo4sl9V/G3s1NzsqiMMZSSVfM7k.nUhq
    jwt-secret: |
      09df1191df5809c93b9778e9f2c13b405dbd6d8ff426fbda11ccb7af0a2b072d
    session-key: |
      b0b0e06a0a70db2bbff13131e10a644d188e878c2ad6aff23f2a0de17ed57f15
```

**Note:** With `mutableSettings = true`, these secrets won't overwrite your existing config, but they're required by the nixpkgs service module.

### API Key Configuration

The API key for the VR helper is now stored in `configVars` at build time rather than as a runtime secret. Add it to your flake configuration:

```nix
# In your vars/default.nix or similar
configVars.networking.stash.apiKey = {
  durin = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...";
  smeagol = "another-api-key...";
};
```

### Secret Naming Convention

Format: `stash/${hostname}/<secret-type>`

Where:
- `${hostname}` is from `config.networking.hostName`
- `<secret-type>` is one of: `password`, `jwt-secret`, `session-key`

## Migration Steps

### Step 1: Add Secrets for One Machine

1. SSH into a machine (e.g., durin)
2. Extract the four values from `/var/lib/stashapp/.stash/config.yml`
3. Add them to your nix-secrets repository as shown above
4. Encrypt with sops: `sops secrets.yaml`
5. Commit and push the secrets

### Step 2: Update Machine Configuration

Edit the machine's `default.nix` (e.g., `/hosts/durin/default.nix`):

**Before:**
```nix
imports = [
  # ... other imports ...
  "hosts/common/optional/services/stashapp.nix"
];
```

**After:**
```nix
imports = [
  # ... other imports ...
  "hosts/common/optional/services/stash.nix"
];
```

### Step 3: Test the Configuration

```bash
# Dry build to check for errors
sudo nixos-rebuild dry-build --flake .#durin

# Test without making it permanent (won't persist across reboots)
sudo nixos-rebuild test --flake .#durin
```

### Step 4: Verify Services

Check that both services are running:

```bash
# Check stash service
systemctl status stash.service

# Check stash-vr service
systemctl status stash-vr.service

# View logs if needed
journalctl -u stash.service -f
journalctl -u stash-vr.service -f
```

### Step 5: Verify Functionality

1. Access Stash web interface: `http://localhost:9999`
2. Check that your library, settings, and data are intact
3. Test VR helper: `http://localhost:9666`
4. Verify you can still authenticate

### Step 6: Make It Permanent

If everything works:

```bash
# Make the configuration permanent
sudo nixos-rebuild switch --flake .#durin
```

### Step 7: Migrate Other Machines

Repeat steps 1-6 for each machine:
- **smeagol** - Active machine
- **bert** - Archived machine (optional)

## Troubleshooting

### Service Won't Start

**Check the logs:**
```bash
journalctl -u stash.service -e
```

**Common issues:**
- Missing or incorrect secrets
- Path permissions for data directory
- Port already in use

### Data Directory Issues

The service expects data at: `/var/lib/stashapp/.stash/`

If your config is elsewhere, update `services.stash.dataDir` in `stash.nix`.

### VR Helper Can't Connect

**Check the API key:**
```bash
# View the generated environment file
sudo cat /run/secrets-rendered/stash-vr-api.env
```

Should contain: `STASH_API_KEY=<your-api-key>`

### Secrets Not Decrypting

**Verify sops configuration:**
```bash
# Check if secrets are properly configured
nix-instantiate --eval -E '(import <nixpkgs/nixos> {}).config.sops.secrets' | jq .
```

## Rollback Plan

If you need to rollback:

1. Change import back to `stashapp.nix`
2. Run `sudo nixos-rebuild switch`
3. The old service will take over

Your data and config.yml remain unchanged throughout this process.

## Service Comparison

### Old Service (`services.stashapp`)
- Custom module in this repository
- Data dir: `/var/lib/stashapp` (with `.stash` subdirectory)
- Config: Managed entirely in config.yml
- User: `stashapp`

### New Service (`services.stash`)
- Official nixpkgs module
- Data dir: `/var/lib/stashapp/.stash` (configured to match existing)
- Config: Can be managed via nix or config.yml (we use existing config.yml)
- User: `stashapp` (configured to match existing)
- VR Helper: Extended via `stash-vr-helper` module

## Benefits of Migration

1. **Upstream Support** - Official nixpkgs module gets updates and maintenance
2. **Better Security** - Proper secret management with sops-nix
3. **Standardization** - Follows nixpkgs conventions
4. **Flexibility** - More configuration options available
5. **No Data Loss** - Existing config and data preserved

## Questions or Issues?

If you encounter any problems during migration, check:
1. This guide's troubleshooting section
2. Service logs with `journalctl`
3. Nixpkgs stash module source: `./stash.nix` (downloaded from nixpkgs)

