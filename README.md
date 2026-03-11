# NixOS Configuration Repository

This repository contains a comprehensive NixOS/Nix-Darwin configuration managing a fleet of heterogeneous machines using Nix flakes. The design emphasizes code reuse, modularity, and clear organization to minimize configuration duplication across systems.

## Quick Start

After cloning this repo, set up the git pre-commit hooks:

```bash
nix develop
```

That's it — the dev shell automatically installs a `.git/hooks/pre-commit` script (managed by Nix) that runs formatting and safety checks on every commit. You only need to do this once per clone.

To update only specific inputs (eg, nix-secrets and nixpkgs-unstable):

```bash
nix flake lock --update-input nix-secrets --update-input nixpkgs-unstable
```

To evaluate a system's config without building it (catches typos across all systems):

```bash
# Single NixOS system
nix eval .#nixosConfigurations.estel.config.system.build.toplevel --apply 'drv: drv.drvPath'

# All active NixOS systems
for system in pangolin11 smeagol barliman estel bombadil durin; do
  printf "%-12s " "$system"
  nix eval .#nixosConfigurations.$system.config.system.build.toplevel \
    --apply 'drv: drv.drvPath' 2>&1 | tail -1
done

# Darwin system
nix eval .#darwinConfigurations.macbookpro.config.system.build.toplevel \
  --apply 'drv: drv.drvPath'

# Home Manager only systems
nix eval ".#legacyPackages.x86_64-linux.homeConfigurations.deck@steamdeck.activationPackage" \
  --apply 'drv: drv.drvPath'
```

Note: evaluation of x86\_64-linux systems from a macOS host requires at least one remote builder
to be reachable (see `hosts/common/darwin/optional/nix-remote-builders.nix`).

## Repository Structure

### Core Directories

- **`flake.nix`** - Main flake definition containing all machine configurations
- **`hosts/`** - NixOS system-level configurations
  - `common/core/` - Required base system configuration (auto-imported)
  - `common/optional/` - Optional system features (import as needed)
  - `common/users/` - User account definitions
  - `common/darwin/` - macOS-specific shared modules
  - `[machine]/` - Machine-specific system configurations
- **`home/`** - Home Manager user environment configurations
  - `tdoggett/common/core/` - Required base home configuration
  - `tdoggett/common/optional/` - Optional home features
  - `tdoggett/[machine].nix` - Machine-specific home configurations
  - `tdoggett/persistence/` - Per-machine impermanence settings
- **`modules/`** - Custom NixOS, nix-darwin, and Home Manager modules
- **`pkgs/`** - Custom package definitions
- **`overlays/`** - Package overlays and modifications
- **`lib/`** - Utility functions and helpers
- **`vars/`** - Global variables and configuration constants

### Configuration Philosophy

**Modularity First**: Each machine's configuration should be easily understood by examining only:
1. The imports list (showing which features are enabled)
2. A small set of machine-specific configuration options

**Shared by Default**: Common configurations live in `hosts/common/` and `home/common/` directories. Machine-specific files should only contain settings that are truly unique to that machine.

**Example Machine Configuration Structure**:
```nix
# hosts/pangolin11/default.nix
{
  imports = [
    ./hardware-configuration.nix
    ./persistence.nix
  ] ++ (map configLib.relativeToRoot [
    "hosts/common/core"                    # Required base config
    "hosts/common/optional/steam.nix"      # Optional: Steam gaming
    "hosts/common/users/${configVars.username}"
  ]);

  # Only machine-specific settings here
  networking.hostName = "pangolin11";
  stylix.image = ./wallpaper.jpg;
}
```

## Machine Fleet

### NixOS Systems (Full System Control)
- **pangolin11** - System76 Pangolin 11 laptop (primary development)
- **barliman** - AMD Framework Desktop (testbed, gaming)
- **smeagol** - AMD desktop (GPU/AI workloads, Docker)
- **durin** - KAMRUI E2 Mini PC (lightweight services)
- **estel** - Beelink SER5 Mini PC (media, 24/7 automation)
- **bombadil** - Linode 4GB VPS (web services — watch RAM!)

### Nix-Darwin Systems (macOS with Nix)
- **macbookpro** - Corporate MacBook Pro (limited by corporate policies)

### Home Manager Only (Limited System Access)
- **steamdeck** - Steam Deck (SteamOS with HM overlay)

### Archived Systems
NixOS (in `hosts/archived/`): thinkpadx1, melian, sauron, bert, glorfindel, fedibox
HM-only (in `home/tdoggett/archived/`): vm1

## Key Features & Technologies

- **Nix Flakes** - Modern, reproducible configuration management
- **Home Manager** - Declarative user environment management
- **Impermanence** - Ephemeral root filesystem with selective persistence
- **SOPS-nix** - Encrypted secrets management
- **Stylix** - System-wide theming and styling
- **Lanzaboote** - Secure Boot support for NixOS

## Development Roadmap

### Completed ✅
 * [X] ~~Finish moving Wordpress from elrond to glorfindel~~ - Migration completed
 * [X] ~~Fix custom Wordpress plugins from breaking `nix flake check`~~ - Moved to separate flake repo
 * [X] ~~Add fedibox configuration~~ - Merged into bombadil configuration
 * [X] ~~Fix and add steamdeck HM configuration~~ - Steam Deck now managed via Home Manager
 * [X] ~~Remove references to diskio~~ - No longer needed for existing systems
 * [X] ~~Figure out email alerts for failed auto-updates~~ - Systems like glorfindel now send failure notifications
 * [X] ~~Look into nix-mineral for security hardening~~ - Using NixOS hardening guides instead
 * [X] ~~Local remote builds~~ - `nix-remote-builders.nix` in place on macbookpro; eval commands cover NixOS, Darwin, and HM-only systems
 * [X] ~~Clean up configuration of pangolin11, thinkpadx1, and melian~~ - pangolin11 is lean and import-driven; thinkpadx1 and melian are archived

### High Priority 🔥
 * [ ] **Implement better deployment workflow** - Deploy uncommitted changes to remote machines for testing
 * [ ] **Clean commit history** - Rebase entire history to remove "Typo" and "Fixes" commits
 * [ ] **Create more `hosts/common` modules** - Move shared configuration out of machine-specific files (ongoing)
 * [ ] **Create more `home/common` modules** - Minimize user-specific declarations in machine files (ongoing)

### Medium Priority 📋
 * [ ] Figure out how to build a VM from configurations for local testing
 * [ ] Investigate `deploy-rs` or similar tools for automated deployment
 * [ ] Implement centralized configuration updates (GitHub Actions + NixOps or similar)
 * [ ] Set up automatic flake input updates for private repos like nix-secrets
 * [ ] Create better testing infrastructure and CI/CD pipeline

### Low Priority 🔮
 * [ ] Personal resume site with auto-updating dates via git hooks
 * [ ] Rebuild work repo auto-download scripts as separate flake
 * [ ] Auto-rebuild personal packages when new stable versions are released
 * [ ] Implement comprehensive documentation and usage examples
 * [ ] Create custom modules for common configuration patterns

### Infrastructure Improvements 🛠️
 * [ ] Better secrets management workflow
 * [ ] Monitoring and alerting for all managed systems
 * [ ] Backup and disaster recovery procedures
 * [ ] Security hardening implementation across all systems
 * [ ] Performance optimization and resource monitoring
