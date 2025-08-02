# NixOS Configuration Repository Context

This repository contains Tom Doggett's comprehensive NixOS/Nix-Darwin configuration for managing a heterogeneous fleet of machines using Nix flakes.

## Repository Purpose & Goals

This is a **shared configuration repository** designed to minimize code duplication across multiple machines while maintaining flexibility for machine-specific configurations. The primary goals are:

1. **Code Reuse**: Extensive use of shared modules in `hosts/common/` and `home/common/` to avoid configuration duplication
2. **Organization**: Clear separation of concerns with structured directories for different aspects of system configuration
3. **Multi-platform Support**: Support for NixOS, Nix-Darwin (macOS), and Home Manager-only configurations
4. **Modularity**: Easy to enable/disable features per machine via imports
5. **Future Streamlining**: Plans to create more custom modules and better testing infrastructure

## Current Challenges & Pain Points

### Deployment Workflow Issues
The current deployment process is cumbersome and leads to messy commit history:
1. Make changes on one machine
2. Test locally (limited testing capabilities)
3. Commit and push changes
4. Pull on remote machine(s)
5. Rebuild and watch for failures
6. Fix failures directly on remote machines
7. Commit and push fixes ("Typo", "Fixes" commits)
8. Pull back to original machine
9. Repeat cycle

**Desired Improvements:**
- Deploy uncommitted changes to remote machines for testing
- Build remote machine configurations locally to verify compatibility before committing
- Rebase commit history to be cleaner and more meaningful
- Better testing infrastructure

### Configuration Organization
Currently working toward better organization where:
- Machine-specific host files (`hosts/*/default.nix`) should only contain machine-unique configurations
- Machine-specific home files (`home/tdoggett/*.nix`) should only contain user-specific settings for that machine
- Most configuration should be handled by shared modules in `hosts/common/` and `home/common/`
- **Goal**: Each machine's configuration should be easily understood by looking at imports and a small set of unique options

## Architecture Overview

### Machine Types
- **NixOS Systems**: Full NixOS installations (most machines)
- **Nix-Darwin**: Corporate MacBook Pro running macOS with Nix-Darwin + Home Manager
- **Home Manager Only**: Steam Deck and work VMs with limited system access

### Repository Structure

```
├── flake.nix                    # Main flake definition with all machine configurations
├── hosts/                      # NixOS system configurations
│   ├── common/                 # Shared system modules
│   │   ├── core/              # Required base configuration
│   │   ├── darwin/            # macOS-specific shared modules
│   │   ├── optional/          # Optional feature modules
│   │   └── users/             # User account definitions
│   └── [machine]/             # Machine-specific system config
│       ├── default.nix        # Main system config (should be minimal)
│       ├── hardware-configuration.nix
│       └── persistence.nix    # Impermanence configuration
├── home/                      # Home Manager configurations
│   └── tdoggett/              # User-specific configurations
│       ├── common/            # Shared home modules
│       │   ├── core/         # Required base home config
│       │   └── optional/     # Optional home feature modules
│       ├── [machine].nix     # Machine-specific home config (should be minimal)
│       └── persistence/      # Per-machine persistence configs
├── modules/                   # Custom modules
│   ├── nixos/                # Custom NixOS modules
│   ├── darwin/               # Custom nix-darwin modules
│   └── home-manager/         # Custom Home Manager modules
├── pkgs/                     # Custom packages
├── lib/                      # Utility functions
├── vars/                     # Global variables and configuration
└── overlays/                 # Package overlays
```

### Machine Fleet
- **pangolin11**: System76 laptop (primary development machine)
- **thinkpadx1**: ThinkPad X1 Carbon laptop
- **melian**: Asus Zenbook 13 laptop
- **smeagol**: AMD desktop (dual boot)
- **sauron**: Windows WSL2 NixOS
- **bert**: Raspberry Pi 4 (home server)
- **glorfindel**: Linode VPS (web services)
- **bombadil**: Linode VPS (web services)
- **fedibox**: AWS EC2 (fediverse services)
- **macbookpro**: Corporate MacBook Pro (Nix-Darwin)
- **steamdeck**: Steam Deck (Home Manager only)
- **vm1**: Work Ubuntu VM (Home Manager only)

## Development Patterns

### Configuration Philosophy
- **Imports over inline config**: Use `configLib.relativeToRoot` for clean import lists
- **Optional modules**: Features are opt-in via imports, not enabled by default
- **Shared defaults**: Common configurations live in `common/` directories
- **Machine specificity**: Only truly unique settings in machine-specific files

### Current Import Pattern
```nix
imports = [
  # Hardware and core requirements
  ./hardware-configuration.nix
  ./persistence.nix
  
  # External module integrations
  inputs.some-input.nixosModules.default
] ++ (map configLib.relativeToRoot [
  # Required shared configuration
  "hosts/common/core"
  
  # Optional features specific to this machine
  "hosts/common/optional/feature1.nix"
  "hosts/common/optional/feature2.nix"
  
  # User configurations
  "hosts/common/users/${configVars.username}"
]);
```

## Key Technologies & Integrations

- **Flakes**: Modern Nix configuration management
- **Home Manager**: User environment management
- **Impermanence**: Ephemeral root filesystem with selective persistence
- **SOPS**: Secrets management
- **Stylix**: System-wide theming
- **Lanzaboote**: Secure Boot support
- **Hyprland**: Wayland compositor (primary desktop)

## Testing & Validation Commands

For flake validation:
```bash
nix flake check --no-build --all-systems
```

For updating specific inputs:
```bash
nix flake lock --update-input nix-secrets --update-input nixpkgs-unstable
```

## Future Improvements Needed

1. **Better Testing**: Local building of remote configurations before deployment
2. **Deployment Automation**: Tools like `deploy-rs` or custom deployment scripts
3. **Module Creation**: More custom modules for common patterns
4. **Documentation**: Better inline documentation and usage examples
5. **History Cleanup**: Rebase messy commit history
6. **Centralized Updates**: Automatic pulling and rebuilding on configuration changes