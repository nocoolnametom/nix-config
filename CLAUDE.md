# NixOS Configuration Repository Context

Tom Doggett's NixOS/Nix-Darwin flake configuration for managing multiple machines with shared modules.

## Common Tasks (by frequency)

1. **Updating inputs and handling rebuild failures** - Most common
2. **Adding services to specific systems** - e.g., AI image generators
3. **Adding features across desktop systems** - e.g., new fonts
4. **Creating custom packages** - When upstream unavailable/outdated
5. **Planning future systems** - Before hardware acquired

## Configuration Philosophy

- **Modular**: Features are opt-in via imports in `hosts/common/optional/` and `home/tdoggett/common/optional/`
- **Shared by default**: Machine configs should be minimal, mostly imports
- **Use `configLib.relativeToRoot`** for clean import paths
- **Directory structure**:
  - `hosts/` - System-level configuration
  - `home/` - User-level configuration (Home Manager)
  - `modules/` - Custom NixOS/Darwin/HM modules
  - `pkgs/` - Custom packages
  - `vars/` - Global constants

## Active Machines

**NixOS Systems**: pangolin11 (dev laptop), barliman (testbed), smeagol (GPU/Docker), durin (mini server), estel (media server), bombadil (VPS)
**Nix-Darwin**: macbookpro (work)
**Home Manager Only**: steamdeck, vm1 (work)
**Archived**: bert, fedibox, william, thinkpadx1, melian, sauron, glorfindel (in `hosts/archived/` and `home/tdoggett/archived/`)

### Machine Decision Matrix

| Machine | GUI | Power | RAM | Best For |
|---------|-----|-------|-----|----------|
| pangolin11 | ✓ | High | 32GB | Primary dev, testing new features |
| barliman | ✓ | High | 32GB | Testbed, gaming |
| smeagol | ✓ | High | 32GB | GPU/AI workloads, Docker |
| durin | ✗ | Low | 8GB | Lightweight services |
| estel | ✗ | Med | 16GB | Media, 24/7 automation |
| bombadil | ✗ | Low | 4GB | **VPS - watch RAM!** Web services |
| macbookpro | ✓ | High | 16GB | Work (restrictions) |
| steamdeck | ✓ | Med | 16GB | Gaming (HM only, read-only) |
| vm1 | ✓ | Low | 8GB | Work VM (HM only) |

**Quick Guide**: Desktop features → pangolin11/barliman/smeagol/macbookpro | Heavy AI/video → smeagol/pangolin11/barliman | 24/7 services → durin/estel/bombadil

## Key Technologies

- **Nix Flakes** + **Home Manager** + **Nix-Darwin** (macOS)
- **SOPS** (secrets), **Lanzaboote** (Secure Boot), **Impermanence** (ephemeral root)
- **Stylix** (theming), **Arion** (Docker Compose on smeagol)
- Custom modules: stashapp, kavitan, per-user-vpn, dns-failover, rsync-cert-sync
- Custom packages: religious sites (journalofdiscourses, mormoncanon), stashapp, CBZ tools
- Private repos: my-wordpress-plugins, my-sd-models, nix-secrets (SSH auth required)

## Standard Import Pattern

```nix
imports = [
  ./hardware-configuration.nix
  ./persistence.nix  # if applicable
] ++ (map configLib.relativeToRoot [
  "hosts/common/core"
  "hosts/common/optional/feature.nix"
  "hosts/common/users/${configVars.username}"
]);
```

**Special args available**: `inputs`, `outputs`, `configVars`, `configLib`, `nixpkgs`, `configurationRevision`

## Essential Commands

```bash
# Build & switch
sudo nixos-rebuild switch --flake .#hostname
darwin-rebuild switch --flake ~/.config/nix-darwin#macbookpro
home-manager switch --flake .#user@hostname

# Update inputs & rebuild
nix flake update
sudo nixos-rebuild switch --flake .#$(hostname)

# Debug build failures
nixos-rebuild build --flake .#hostname --show-trace

# Package versions available
pkgs.packageName           # nixos-unstable (default)
pkgs.stable.packageName    # 25.05 stable
pkgs.bleeding.packageName  # master branch
```

## Handling Update Failures (Most Common Task)

After `nix flake update`, builds often fail. **Resolution steps**:

1. Run with trace: `nixos-rebuild build --flake .#hostname --show-trace`
2. Identify failing package/service from error
3. Comment out the failing optional import temporarily:
   ```nix
   # Disabled 2024-11-27: Build failure after nixpkgs update, TODO: re-enable
   # "hosts/common/optional/broken-service.nix"
   ```
4. Common culprits: custom packages in `pkgs/` (may need hash updates), AI/ML packages, bleeding-edge services
5. Test on non-critical machines first (pangolin11, barliman)

## Quick Workflows

**Add service to specific machine**: Check if module exists in `hosts/common/optional/`, import it or create new one, add import to target machine(s)

**Add desktop feature**: Create in `hosts/common/optional/` with conditional logic (`lib.mkIf config.services.xserver.enable`), import on desktop machines

**Create custom package**: Use `pkgs/new-package/default.nix` with `lib.fakeHash` initially, get real hash from build error. For unmerged PRs, copy definition from GitHub PR.

**Get package hash**: `nix-prefetch-github owner repo --rev v1.2.3` or use `lib.fakeHash` and let build tell you

## Other Common Tasks

**Archive a machine**: Move to `hosts/archived/`, reorganize home configs to `home/tdoggett/archived/machine/`, update networking in nix-secrets to `networking.archived.*`, move flake entry to `archivedNixosConfigurations`

**Add new machine**: `nixos-generate-config`, create `hosts/newmachine/` with minimal config, create `home/tdoggett/newmachine.nix`, add to `flake.nix`

**Update custom packages**: Many have update scripts (e.g., `cd pkgs/stashapp && ./update_hashes.sh`)

## Important Notes

**Impermanence**: Several machines wipe root on boot. Only `/nix`, `/boot`, and explicitly persisted directories survive. Check `persistence.nix` files.

**Private repos**: `my-wordpress-plugins`, `my-sd-models`, `nix-secrets` require SSH auth on each machine.

**Archived systems**: Networking data in `nix-secrets` under `networking.archived.*`. Active systems may reference archived networking. Not actively maintained, expect build errors.

**Darwin-specific**: macbookpro uses Nix-Darwin, different module paths (`hosts/work/macbookpro/`).

**Multiple nixpkgs versions**: Default `pkgs.*` uses nixos-unstable. Also available: `pkgs.stable.*` (25.05), `pkgs.bleeding.*` (master), `pkgs-old.*` (24.11).

## Bombadil Failover Certificate System

**Critical**: Failover certs MUST be in `/var/lib/acme-failover/`, NOT `/var/lib/acme/` (causes permission conflicts)

**How it works**: estel's `rsync-cert-sync` syncs certs to bombadil's `/var/lib/acme-failover/` → `rsync-cert-fix-permissions` fixes ownership → nginx uses them

**Config files**: `modules/nixos/rsync-cert-sync.nix`, `hosts/bombadil/nginx.nix`, `modules/nixos/failover-redirects.nix`

**Common issue**: ACME 403 errors → fix permissions: `sudo chown -R acme:nginx /var/lib/acme/acme-challenge/ && sudo chmod -R 755 /var/lib/acme/acme-challenge/`

## Commit Message Conventions

`flake:` inputs/structure | `pkgs:` custom packages | `modules:` custom modules | `hosts:` system configs | `home:` HM configs | `feat:` new features | `fix:` bugs | `refactor:` reorganization | `docs:` documentation