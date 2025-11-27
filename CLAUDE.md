# NixOS Configuration Repository Context

This repository contains Tom Doggett's comprehensive NixOS/Nix-Darwin configuration for managing a heterogeneous fleet of machines using Nix flakes.

## AI Assistant Guidelines

When helping with this repository, prioritize these common workflows (ordered by frequency):

1. **Updating inputs and handling rebuild failures** - Most common task
2. **Adding new services to specific systems** - Frequent (e.g., AI image generators)
3. **Adding features across all desktop systems** - Regular (e.g., new fonts)
4. **Creating custom packages** - When upstream packages are unavailable/outdated
5. **Planning future systems** - Before hardware is acquired

### Key Assistance Patterns

- **For rebuild failures**: Help identify which services/modules to comment out when dependencies fail
- **For new packages**: Assist in fetching source from GitHub PRs/MRs, writing derivations, creating update scripts
- **For planned systems**: Create placeholder configurations even before hardware exists
- **For cross-system features**: Know which machines have desktop environments vs servers
- **For service additions**: Understand which optional modules already exist vs need creation

## Repository Purpose & Goals

This is a **shared configuration repository** designed to minimize code duplication across multiple machines while maintaining flexibility for machine-specific configurations. The primary goals are:

1. **Code Reuse**: Extensive use of shared modules in `hosts/common/` and `home/common/` to avoid configuration duplication
2. **Organization**: Clear separation of concerns with structured directories for different aspects of system configuration
3. **Multi-platform Support**: Support for NixOS, Nix-Darwin (macOS), and Home Manager-only configurations
4. **Modularity**: Easy to enable/disable features per machine via imports
5. **Custom Modules**: Extensive custom modules for specialized functionality (stashapp, kavitan, per-user-vpn, etc.)
6. **Custom Packages**: Multiple custom packages maintained in-tree

## Configuration Philosophy

The repository follows these key principles:

### Modularity First
Each machine's configuration should be easily understood by examining only:
1. The imports list (showing which features are enabled)
2. A small set of machine-specific configuration options

### Shared by Default
- Common configurations live in `hosts/common/` and `home/common/` directories
- Machine-specific files (`hosts/*/default.nix`, `home/tdoggett/*.nix`) should only contain settings truly unique to that machine
- Features are opt-in via imports, not enabled by default
- Use `configLib.relativeToRoot` for clean import lists

### Clear Separation
- **System-level** configuration: `hosts/`
- **User-level** configuration: `home/`
- **Custom functionality**: `modules/`
- **Custom software**: `pkgs/`
- **Global constants**: `vars/`

## Architecture Overview

### Machine Types & Current Fleet

#### Active NixOS Systems
- **pangolin11**: System76 Pangolin 11 AMD laptop - primary development machine (desktop GUI, powerful)
- **barliman**: AMD Framework desktop (dual boot) - workstation (desktop GUI, powerful, testbed)
- **smeagol**: AMD desktop (dual boot) - workstation with Docker/Arion support (desktop GUI, powerful, GPU)
- **bert**: Raspberry Pi 4 - home server (headless, aarch64-linux, low-power, avoid heavy services)
- **estel**: Beelink SER5 Mini PC - media/home automation server (headless, powerful enough for media)
- **bombadil**: Linode 4GB VPS - web services (headless, limited RAM, WordPress, nginx)
- **fedibox**: AWS EC2 instance - Fediverse services (headless, cloud)

#### Nix-Darwin System
- **macbookpro**: Corporate MacBook Pro with Nix-Darwin + Home Manager (GUI, work restrictions)

#### Home Manager Only
- **steamdeck**: Valve Steam Deck with limited system access (gaming-focused, read-only system)
- **vm1**: Work Ubuntu VM with Home Manager only (limited access, work restrictions)

#### Archived Systems (maintained for reference)
Located in `hosts/archived/`:
- **thinkpadx1**: ThinkPad X1 Carbon laptop
- **melian**: Asus Zenbook 13 laptop  
- **william**: Raspberry Pi 5
- **sauron**: Windows WSL2 NixOS
- **glorfindel**: Linode VPS (replaced by bombadil)

### Machine Characteristics for AI Assistants

When suggesting features or services, consider these machine profiles:

| Machine | GUI | Power | RAM | Special Notes |
|---------|-----|-------|-----|---------------|
| pangolin11 | ✓ Desktop | High | 32GB+ | Primary dev machine, test new features here |
| barliman | ✓ Desktop | High | 32GB+ | Workstation, good testbed |
| smeagol | ✓ Desktop | High | 32GB+ | Has GPU, Docker/Arion, AI workloads |
| bert | ✗ Headless | Low | 4GB | Raspberry Pi - avoid heavy services |
| estel | ✗ Headless | Medium | 16GB | Media server, 24/7 uptime |
| bombadil | ✗ Headless | Low | 4GB | VPS - watch RAM usage |
| fedibox | ✗ Headless | Medium | Varies | Cloud - web-facing services |
| macbookpro | ✓ Desktop | High | 16GB+ | Work machine - corporate restrictions |
| steamdeck | ✓ Gaming | Medium | 16GB | Read-only system, HM only |
| vm1 | ✓ Desktop | Low | 8GB | Work VM - HM only, restrictions |

**Decision Matrix:**
- **Desktop features** (fonts, themes, GUI apps): pangolin11, barliman, smeagol, macbookpro
- **Heavy services** (AI, video processing): pangolin11, barliman, smeagol, estel
- **24/7 services** (monitoring, automation): bert, estel, bombadil, fedibox
- **GPU workloads** (AI image gen, ML): smeagol primarily
- **Public web services**: bombadil, fedibox
- **Local network services**: bert, estel

### Repository Structure

```
├── flake.nix                    # Main flake with nixosConfigurations, darwinConfigurations, homeConfigurations
├── shell.nix                    # Development shell with tools for working with this config
├── checks/                      # Flake check validations
├── hosts/                       # NixOS & nix-darwin system configurations
│   ├── common/                  # Shared system modules
│   │   ├── core/               # Required base configuration (auto-imported)
│   │   ├── darwin/             # macOS-specific shared modules
│   │   ├── optional/           # Optional feature modules (import as needed)
│   │   └── users/              # User account definitions
│   ├── archived/               # Legacy systems maintained for reference
│   ├── work/                   # Work-specific machine configs
│   └── [machine]/              # Active machine-specific system configs
│       ├── default.nix         # Main system config (should be minimal)
│       ├── hardware-configuration.nix
│       └── persistence.nix     # Impermanence configuration (if applicable)
├── home/                       # Home Manager configurations
│   └── tdoggett/               # User-specific configurations
│       ├── common/             # Shared home modules
│       │   ├── core/          # Required base home config
│       │   └── optional/      # Optional home feature modules
│       ├── persistence/       # Per-machine persistence configs
│       ├── [machine].nix      # Machine-specific home config (should be minimal)
│       └── nixos.nix          # Generic NixOS home config
├── modules/                    # Custom modules extending NixOS/HM functionality
│   ├── nixos/                 # Custom NixOS modules (14+ custom modules)
│   │   ├── stashapp.nix       # Stash media server
│   │   ├── kavitan.nix        # Kavita manga/comic reader
│   │   ├── per-user-vpn.nix   # Per-user VPN routing
│   │   ├── dns-failover.nix   # DNS failover service
│   │   ├── systemd-failure-alert.nix
│   │   └── ... (and more)
│   ├── darwin/                # Custom nix-darwin modules
│   └── home-manager/          # Custom Home Manager modules
│       ├── waycorner.nix      # Wayland corner actions
│       ├── waynergy.nix       # Wayland Synergy
│       └── ...
├── pkgs/                      # Custom packages (8+ packages)
│   ├── homer/                 # Homer dashboard
│   ├── phanpy/                # Phanpy Mastodon client
│   ├── stashapp/              # Stash media server package
│   ├── stash-vr/              # Stash VR plugin
│   ├── stashapp-tools/        # Stash utilities
│   ├── split-my-cbz/          # Comic book utilities
│   ├── update-cbz-tags/       # Comic book metadata tools
│   └── wakatime-zsh-plugin/   # Wakatime shell integration
├── lib/                       # Utility functions (e.g., relativeToRoot)
├── vars/                      # Global variables and configuration constants
└── overlays/                  # Package overlays (stable-packages, unstable-packages)
```

## Key Technologies & Integrations

### Core Infrastructure
- **Nix Flakes**: Modern Nix configuration with pinned dependencies and reproducible builds
- **Home Manager**: Declarative dotfiles and user environment management
- **Nix-Darwin**: macOS system configuration with Nix

### Security & Secrets
- **SOPS (sops-nix)**: Encrypted secrets management with age/PGP
- **Lanzaboote**: Secure Boot support for NixOS systems
- **YubiKey**: Hardware security key support across systems

### System Features
- **Impermanence**: Ephemeral root filesystem with selective persistence on several machines
- **Stylix**: System-wide theming and colorscheme management
- **Arion**: Docker Compose management with Nix on smeagol

### Hardware Support
- **nixos-hardware**: Hardware-specific optimizations
- **nixos-raspberrypi**: Raspberry Pi 4/5 support  
- **Jovian**: SteamOS-like features for Steam Deck
- **NixOS-WSL**: Windows Subsystem for Linux integration (archived)

### Development Tools
- **Nixified-AI**: AI model management and Stable Diffusion
- **Helium**: Floating browser for PiP
- **Pre-commit hooks**: Git hooks for code quality

### Cloud & Services
- **Nix-Flatpak**: Declarative Flatpak management (like Homebrew on macOS)
- **Apple Fonts**: San Francisco and other Apple fonts for macOS-like theming

### Personal Integrations
- **my-wordpress-plugins**: Custom WordPress themes and plugins (private repo)
- **my-sd-models**: Stable Diffusion models for various machines (private repo)
- **nix-secrets**: Private secrets and sensitive configuration (private SSH-authenticated repo)
- **disposable-email-domains**: Email validation data

## Development Patterns

### Standard Import Pattern
```nix
imports = [
  # Hardware and core requirements
  ./hardware-configuration.nix
  ./persistence.nix
  
  # External module integrations
  inputs.some-input.nixosModules.default
] ++ (map configLib.relativeToRoot [
  # Required shared configuration (auto-imported by core)
  "hosts/common/core"
  
  # Optional features specific to this machine
  "hosts/common/optional/feature1.nix"
  "hosts/common/optional/feature2.nix"
  
  # User configurations
  "hosts/common/users/${configVars.username}"
]);
```

### Available Special Arguments
All NixOS, Darwin, and Home Manager configurations have access to:
- `inputs`: All flake inputs
- `outputs`: Flake outputs (packages, modules, etc.)
- `configVars`: Global variables from `vars/`
- `configLib`: Utility functions from `lib/` (notably `relativeToRoot`)
- `nixpkgs`: The nixpkgs flake input
- `configurationRevision`: Current git revision or dirty state

### Custom Modules Overview

#### NixOS Modules (`modules/nixos/`)
- **stashapp**: Media organization and management server
- **kavitan**: Manga and comic book reader/server
- **per-user-vpn**: Route specific users through VPN
- **dns-failover**: Automatic DNS failover service
- **failover-redirects**: HTTP redirect management during failover
- **systemd-failure-alert**: Notifications for systemd service failures
- **maestral**: Dropbox sync service
- **sauronsync**: Custom sync service
- **rsync-cert-sync**: TLS certificate synchronization
- **stash-video-conversion**: Automated video transcoding for Stash
- **nzbget-to-management**: Usenet download automation
- **yubikey**: YubiKey support and configuration
- **zsa-udev-rules**: ZSA keyboard udev rules
- **deprecation**: Configuration deprecation warnings

#### Home Manager Modules (`modules/home-manager/`)
- **waycorner**: Wayland hot corner actions
- **waynergy**: Wayland Synergy client
- **yubikey-touch-detector**: Visual feedback for YubiKey touches
- **davmail-config**: DavMail Exchange gateway configuration

### Custom Packages (`pkgs/`)
All packages include proper update scripts and are maintained in-tree:
- **homer**: Customizable dashboard for home services
- **phanpy**: Modern Mastodon web client
- **stashapp**: Adult media organizer (with update automation)
- **stash-vr**: VR viewer plugin for Stash
- **stashapp-tools**: Command-line utilities for Stash
- **split-my-cbz**: Comic book archive splitting tool
- **update-cbz-tags**: Comic book metadata management
- **wakatime-zsh-plugin**: WakaTime time tracking for zsh

## Building & Deploying

### Local Builds

#### NixOS Systems
```bash
# Build and switch on current machine
sudo nixos-rebuild switch --flake .#hostname

# Dry-run to see what would change
nixos-rebuild dry-build --flake .#hostname

# Build any machine's config locally (even on a different machine)
nixos-rebuild build --flake .#hostname

# Build with verbose output
sudo nixos-rebuild switch --flake .#hostname -v
```

#### Nix-Darwin (macOS)
```bash
# Build and switch
darwin-rebuild switch --flake ~/.config/nix-darwin#macbookpro

# Dry-run
darwin-rebuild build --flake ~/.config/nix-darwin#macbookpro
```

#### Home Manager Only
```bash
# Build and switch
home-manager switch --flake ~/.config/home-manager#user@hostname

# For Steam Deck
home-manager switch --flake .#deck@steamdeck

# For work VM
home-manager switch --flake .#tdoggett@vm1
```

### Remote Builds

#### Remote Build + Deploy
```bash
# Build locally, deploy to remote (recommended for Raspberry Pi)
nixos-rebuild switch --use-remote-sudo --flake .#bert \
  --target-host bert --build-host localhost --use-substitutes -v

# Build on remote, deploy to remote
nixos-rebuild switch --flake .#hostname --target-host hostname --use-remote-sudo
```

### Flake Management

#### Validation & Checks
```bash
# Run all flake checks (includes archived systems)
nix flake check --no-build --all-systems

# Check with builds (comprehensive but slower)
nix flake check --all-systems

# Format all Nix files with nixfmt-rfc-style
nix fmt
```

#### Updating Dependencies
```bash
# Update specific inputs
nix flake lock --update-input nix-secrets --update-input nixpkgs-unstable

# Update all inputs
nix flake update

# Update and immediately rebuild
nix flake update && sudo nixos-rebuild switch --flake .#$(hostname)
```

### Development Shell
```bash
# Enter development environment with all tools
nix develop

# Run a command in dev shell without entering
nix develop --command <command>
```

## Maintenance & Troubleshooting

### Garbage Collection
```bash
# Delete old generations older than 7 days
sudo nix-collect-garbage --delete-older-than 7d

# Delete all old generations
sudo nix-collect-garbage -d

# Optimize store (deduplicate)
nix-store --optimise
```

### Debugging Build Issues
```bash
# Show trace on evaluation errors
nixos-rebuild build --flake .#hostname --show-trace

# Verbose output with full logs
nixos-rebuild switch --flake .#hostname -v -L

# Check for broken symlinks in result
nix-store --verify --check-contents
```

### Working with Secrets
```bash
# Edit encrypted secrets file
sops secrets/secrets.yaml

# Update keys in secrets file
sops updatekeys secrets/secrets.yaml

# Create new secrets file
sops secrets/new-file.yaml
```

### Package Development
```bash
# Build a custom package
nix build .#packageName

# Build and run
nix run .#packageName

# Enter development shell for a package
cd pkgs/packageName && nix develop
```

## Common Workflows

### Most Common: Updating Inputs and Handling Failures

This is the **most frequent workflow**. After updating nixpkgs, builds often fail due to broken dependencies.

#### Standard Update Process
```bash
# Update all inputs
nix flake update

# Or update specific inputs only
nix flake lock --update-input nixpkgs --update-input nixpkgs-unstable

# Attempt rebuild
sudo nixos-rebuild switch --flake .#$(hostname)
```

#### When Builds Fail After Updates

**Common failure pattern**: A package or service fails to build due to updated dependencies.

**Resolution strategies**:
1. **Comment out failing services temporarily**:
   ```nix
   # In hosts/machine/default.nix or hosts/common/optional/feature.nix
   # services.problematic-service.enable = true;  # Temporarily disabled due to build failure
   ```

2. **Check which optional imports are causing issues**:
   - Look at the error trace to identify failing packages
   - Comment out the related optional module imports
   - Rebuild to verify system works without that feature
   - Re-enable once upstream fixes the issue

3. **Identify the failing module/package**:
   ```bash
   # Build with trace to see full error
   nixos-rebuild build --flake .#hostname --show-trace
   ```

4. **Common culprits after updates**:
   - Custom packages in `pkgs/` (stashapp, phanpy, etc.) - may need hash updates
   - AI/ML packages from nixified-ai
   - Bleeding-edge services with many dependencies
   - Custom modules that depend on unstable packages

5. **Document the workaround**:
   ```nix
   # Disabled 2024-11-27: Build failure in dependency chain after nixpkgs update
   # TODO: Re-enable after upstream fix
   # "hosts/common/optional/ai-tools.nix"
   ```

#### Pro Tips for Update Workflow
- Update frequently (weekly) to avoid large breaking changes
- Test on non-critical machines first (pangolin11, barliman)
- Keep `nixpkgs-old` as a fallback for problematic packages
- Use `nix flake lock --update-input nix-secrets` separately for quick secret updates

### Adding New Services to Specific Systems

When adding services like AI image generators to select machines:

1. **Check if an optional module exists**:
   ```bash
   ls hosts/common/optional/ | grep -i "service-name"
   ```

2. **If it exists, just import it**:
   ```nix
   # In hosts/machine/default.nix
   imports = [ ... ] ++ (map configLib.relativeToRoot [
     "hosts/common/optional/ai-image-generation.nix"
   ]);
   ```

3. **If it doesn't exist, create it**:
   ```bash
   vim hosts/common/optional/new-service.nix
   ```
   ```nix
   { config, pkgs, ... }: {
     # Service configuration here
     services.new-service = {
       enable = true;
       # ... options
     };
   }
   ```

4. **Import on target machines only**:
   - Add to powerful machines: smeagol, barliman, estel
   - Skip on low-power: bert (Raspberry Pi)
   - Skip on remote servers: bombadil, fedibox (unless web-accessible)

### Adding Features Across All Desktop Systems

For system-wide changes like fonts, themes, or desktop utilities:

1. **Identify desktop systems**:
   - **Desktops**: pangolin11, barliman, smeagol
   - **Servers** (no GUI): bert, estel, bombadil, fedibox
   - **Work**: macbookpro (Darwin)
   - **Limited**: steamdeck, vm1 (Home Manager only)

2. **Add to common core or create optional module**:
   ```nix
   # For truly universal desktop features
   vim hosts/common/core/desktop.nix
   
   # Or create optional module
   vim hosts/common/optional/desktop-enhancement.nix
   ```

3. **Use conditional logic for desktop-only features**:
   ```nix
   { config, lib, pkgs, ... }: {
     # Only enable on systems with desktop environments
     fonts.packages = lib.mkIf (config.services.xserver.enable || config.programs.hyprland.enable) [
       pkgs.new-font
     ];
   }
   ```

4. **For Home Manager features**:
   ```nix
   # In home/tdoggett/common/optional/
   vim home/tdoggett/common/optional/desktop-fonts.nix
   ```

### Creating Custom Packages

When nixpkgs doesn't have a package or the version is outdated:

#### From GitHub Release
```nix
# In pkgs/new-package/default.nix
{ lib, stdenv, fetchFromGitHub, ... }:

stdenv.mkDerivation rec {
  pname = "package-name";
  version = "1.2.3";

  src = fetchFromGitHub {
    owner = "username";
    repo = "repo-name";
    rev = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";  # Use lib.fakeHash initially
  };

  # Build instructions...
}
```

#### From Unmerged GitHub PR/MR

**Common scenario**: Package exists in a PR but isn't merged yet (e.g., Kavita version update).

1. **Find the PR/MR**:
   ```bash
   # Search nixpkgs PRs: https://github.com/NixOS/nixpkgs/pulls?q=is%3Apr+kavita
   ```

2. **Extract the package definition**:
   - View the PR's changed files
   - Copy the updated `default.nix`
   - Note any new dependencies

3. **Create local package**:
   ```bash
   mkdir -p pkgs/kavita
   vim pkgs/kavita/default.nix
   # Paste the PR's package definition
   ```

4. **Test the hash**:
   ```bash
   # Build to get actual hash
   nix build .#kavita
   # Update hash in default.nix with error message hash
   ```

5. **Add to flake packages**:
   ```nix
   # Already exported via pkgs/default.nix
   # Just use pkgs.kavita in your config
   ```

6. **Create update script** (optional):
   ```bash
   vim pkgs/kavita/update.sh
   chmod +x pkgs/kavita/update.sh
   ```

#### Getting Correct Hash
```bash
# Method 1: Use lib.fakeHash and let build tell you
hash = lib.fakeHash;  # or sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=

# Method 2: Prefetch
nix-prefetch-github owner repo --rev v1.2.3

# Method 3: For URLs
nix-prefetch-url https://example.com/file.tar.gz
```

### Planning Future/Unbuilt Systems

Create configurations before hardware exists:

1. **Create host directory**:
   ```bash
   mkdir -p hosts/futuresystem
   ```

2. **Create placeholder hardware config**:
   ```nix
   # hosts/futuresystem/hardware-configuration.nix
   { modulesPath, ... }: {
     imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];  # Generic placeholder
     
     # Placeholder - will be replaced after installation
     boot.loader.grub.device = "/dev/sda";
     fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
   }
   ```

3. **Create main config with intended features**:
   ```nix
   # hosts/futuresystem/default.nix
   { inputs, outputs, configLib, configVars, ... }: {
     imports = [ ./hardware-configuration.nix ] ++ (map configLib.relativeToRoot [
       "hosts/common/core"
       "hosts/common/users/${configVars.username}"
       # Intended features
       "hosts/common/optional/ai-services.nix"
       "hosts/common/optional/media-server.nix"
     ]);
     
     networking.hostName = "futuresystem";
     system.stateVersion = "25.11";  # Use current stable
     
     # Intended specifications
     # boot.kernelPackages = pkgs.linuxPackages_latest;
     # Will configure after hardware details known
   }
   ```

4. **Create home config**:
   ```nix
   # home/tdoggett/futuresystem.nix
   { inputs, outputs, configLib, ... }: {
     imports = [ ./nixos.nix ] ++ (map configLib.relativeToRoot [
       "home/tdoggett/common/optional/desktop-full.nix"
     ]);
   }
   ```

5. **Add to flake.nix**:
   ```nix
   nixosConfigurations = {
     # ... existing systems ...
     
     # Future system - hardware not yet acquired
     futuresystem = lib.nixosSystem {
       inherit specialArgs;
       modules = [
         home-manager.nixosModules.home-manager
         { home-manager.extraSpecialArgs = specialArgs; }
         ./hosts/futuresystem
       ];
     };
   };
   ```

6. **Validate it builds**:
   ```bash
   nixos-rebuild build --flake .#futuresystem
   # Should build successfully even without real hardware
   ```

7. **After hardware acquisition**:
   - Boot NixOS installer
   - Run `nixos-generate-config --dir /tmp/config`
   - Replace placeholder `hardware-configuration.nix`
   - Add any hardware-specific options (GPU, etc.)
   - Deploy with `nixos-install --flake .#futuresystem`

## Other Workflows

### Adding a New Machine

1. Generate hardware configuration:
   ```bash
   sudo nixos-generate-config --dir /tmp/config
   ```

2. Create machine directory:
   ```bash
   mkdir -p hosts/newmachine
   cp /tmp/config/hardware-configuration.nix hosts/newmachine/
   ```

3. Create `hosts/newmachine/default.nix`:
   ```nix
   { inputs, outputs, configLib, configVars, ... }: {
     imports = [ ./hardware-configuration.nix ] ++ (map configLib.relativeToRoot [
       "hosts/common/core"
       "hosts/common/users/${configVars.username}"
       # Add optional features as needed
     ]);
     
     networking.hostName = "newmachine";
     system.stateVersion = "25.11";
   }
   ```

4. Create `home/tdoggett/newmachine.nix`:
   ```nix
   { inputs, outputs, configLib, ... }: {
     imports = [ ./nixos.nix ] ++ (map configLib.relativeToRoot [
       # Add optional home features as needed
     ]);
   }
   ```

5. Add to `flake.nix` in `nixosConfigurations`:
   ```nix
   newmachine = lib.nixosSystem {
     inherit specialArgs;
     modules = [
       home-manager.nixosModules.home-manager
       { home-manager.extraSpecialArgs = specialArgs; }
       ./hosts/newmachine
     ];
   };
   ```

6. Build and deploy:
   ```bash
   nixos-rebuild switch --flake .#newmachine
   ```

### Adding a New Optional Feature

1. Create module in `hosts/common/optional/`:
   ```bash
   vim hosts/common/optional/new-feature.nix
   ```

2. Import in machine configs that need it:
   ```nix
   imports = [ ... ] ++ (map configLib.relativeToRoot [
     "hosts/common/optional/new-feature.nix"
   ]);
   ```

### Updating Custom Packages

Many custom packages have update scripts:
```bash
# Update stashapp
cd pkgs/stashapp && ./update_hashes.sh

# Update stash-vr
cd pkgs/stash-vr && ./update_hashes.sh

# Commit the updated hashes
git add pkgs/
git commit -m "pkgs: update stashapp and stash-vr"
```

## Important Notes & Gotchas

### Impermanence
Several machines use impermanence with ephemeral root filesystems:
- Root filesystem is wiped on every boot
- Only `/nix`, `/boot`, and explicitly persisted directories survive
- Check `persistence.nix` files for what's persisted per machine
- Persistence configs are in `home/tdoggett/persistence/` for home directories

### Private Repositories
Three inputs require SSH authentication:
- `my-wordpress-plugins`: WordPress customizations
- `my-sd-models`: AI model configurations (uses shallow clone)
- `nix-secrets`: Sensitive configuration and secrets (uses shallow clone)

These must be accessible via SSH keys configured on each machine.

### Raspberry Pi Building
The Raspberry Pi 4 (bert) is aarch64-linux and should typically be built locally rather than cross-compiled:
- Use `--build-host localhost` when deploying remotely
- Use `--use-substitutes` to pull from binary caches
- Cross-compilation can be slow and may have issues

### Archived Systems
Archived systems in `hosts/archived/` and `archivedNixosConfigurations`:
- Still validated by `nix flake check`
- Serve as reference configurations
- Can still be built and deployed if needed
- Not actively maintained but should remain buildable

### Darwin-Specific
The macOS system (macbookpro) uses:
- Nix-Darwin for system configuration
- Home Manager integrated via darwin modules
- Different module paths (`hosts/work/macbookpro/`)
- Name pulled from `nix-secrets` for privacy

### Multiple Nixpkgs Versions
The flake uses multiple nixpkgs inputs:
- `nixpkgs`: Main package source (nixos-unstable)
- `nixpkgs-stable`: Stable channel (25.05)
- `nixpkgs-unstable`: Explicit unstable (same as nixpkgs currently)
- `nixpkgs-master`: Bleeding edge master branch
- `nixpkgs-old`: Previous release (24.11)

Access via overlays: 
- `pkgs.stable.packageName` - Stable packages (25.05)
- `pkgs.unstable.packageName` - Unstable packages
- `pkgs.bleeding.packageName` - Master branch packages (newest, may be unstable)
- Default `pkgs.packageName` uses nixos-unstable

## Quick Reference for AI Assistants

### When to Create vs Import

| Scenario | Action | Location |
|----------|--------|----------|
| Service exists in nixpkgs | Import and configure | `hosts/common/optional/` |
| Service exists in flake input | Add input, import module | Check input's `.nixosModules` |
| Service doesn't exist | Create custom module | `modules/nixos/` |
| Package doesn't exist | Create custom package | `pkgs/new-package/` |
| Package outdated in nixpkgs | Override or custom package | `pkgs/new-package/` or `overlays/` |
| Package in unmerged PR | Copy to `pkgs/`, credit PR | `pkgs/new-package/` + comment |

### Finding Package/Module Sources

```bash
# Search nixpkgs for package
nix search nixpkgs packagename

# Search for NixOS option
man configuration.nix | grep -A5 "servicename"

# Search online
# https://search.nixos.org/packages
# https://search.nixos.org/options

# Check if package exists in a PR
# https://github.com/NixOS/nixpkgs/pulls?q=is%3Apr+packagename

# Find package source in nixpkgs
nix edit nixpkgs#packagename
```

### Common Import Patterns by Use Case

#### Adding Desktop Features (fonts, themes, GUI apps)
```nix
# Create optional module
vim hosts/common/optional/desktop-enhancement.nix

# Import on desktop systems
# pangolin11, barliman, smeagol: hosts/*/default.nix
# macbookpro: hosts/work/macbookpro/default.nix
```

#### Adding Server Services
```nix
# Create optional module
vim hosts/common/optional/server-service.nix

# Import on appropriate servers
# bert: lightweight services only
# estel: media/automation services
# bombadil: web services (mind RAM)
# fedibox: web-facing services
```

#### Adding AI/ML Services
```nix
# Create optional module
vim hosts/common/optional/ai-service.nix

# Import on powerful machines only
# smeagol: best choice (GPU)
# pangolin11, barliman: also suitable
# estel: maybe (has enough RAM)
# bert, bombadil: avoid (insufficient resources)
```

#### Home Manager Features
```nix
# Create optional module
vim home/tdoggett/common/optional/feature.nix

# Import in machine home configs
# home/tdoggett/{machine}.nix
```

### Troubleshooting Checklist

When a build fails after updates:

1. ✓ Run with `--show-trace` to see full error
2. ✓ Identify the failing package/service name
3. ✓ Search recent nixpkgs issues for the package
4. ✓ Check if it's a custom package needing hash update
5. ✓ Comment out the related optional module import
6. ✓ Add a TODO comment with date and reason
7. ✓ Test rebuild succeeds without it
8. ✓ Document the workaround for future reference

### Package Version Strategies

| Situation | Strategy | Implementation |
|-----------|----------|----------------|
| Need older stable version | Use `pkgs.stable.package` | Already available via overlay |
| Need newer unstable | Use `pkgs.unstable.package` | Already available via overlay |
| Need bleeding edge from master | Use `pkgs.bleeding.package` | Already available via overlay |
| Need specific old version | Use `pkgs-old.package` | Reference `nixpkgs-old` input |
| Need from GitHub directly | Fetch from GitHub directly | Create package in `pkgs/` |
| Need unmerged PR version | Copy PR's derivation | Create in `pkgs/`, note PR# |
| Need to pin specific commit | Use `fetchFromGitHub` with rev | In custom package |

### Testing Strategy for Changes

Before committing, test in this order:

1. **Local machine** (wherever you're working)
2. **Testbed machine** (barliman is good for this)
3. **Production machines** if tests pass
4. **Low-priority machines last** (bert, archived systems)

For flake-only changes (no system changes):
```bash
nix flake check --no-build --all-systems  # Fast validation
```

For local testing of other machine configs:
```bash
nixos-rebuild build --flake .#other-machine  # Build without switching
```

### Suggested Commit Message Conventions

Use prefixes to categorize changes:

- `flake:` - Changes to flake.nix, inputs, or flake structure
- `pkgs:` - Custom package additions or updates
- `modules:` - Custom module changes
- `hosts:` - Host-specific configuration changes
- `home:` - Home Manager configuration changes
- `feat:` - New features across multiple areas
- `fix:` - Bug fixes
- `refactor:` - Code reorganization without functionality changes
- `docs:` - Documentation updates

Examples:
```
flake: update nixpkgs and nixpkgs-unstable
pkgs: update stashapp to v0.25.1
modules: add kavitan manga server module
hosts(smeagol): enable AI image generation services
home: add JetBrains Mono font to all desktops
feat: add support for future system 'newmachine'
fix(bert): disable failing service after update
refactor: consolidate desktop feature imports
```