# NixOS Configuration Repository Context

Tom Doggett's NixOS/Nix-Darwin flake configuration for managing multiple machines with shared modules.

This file is the tool-neutral guide for anyone, human or coding agent, working in this repo.
Tool-specific notes live in that tool's own file (e.g. `CLAUDE.md`).

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

## Repo Rules

- **Services are common modules; hosts stay thin.** Put a service in `hosts/common/optional/services/`
  (container-based ones in `hosts/common/optional/services/docker/`), expose `services.<name>.*` options
  for anything host-specific (data paths, ports) with generic `/var/lib/<name>` defaults, and have the
  host only import it and set those options. A host directory holds only `default.nix`,
  `hardware-configuration.nix` and `persistence.nix` (a few deliberate exceptions exist, e.g.
  `hosts/estel/caddy.nix`, `hosts/feanor/backup.nix`, `hosts/feanor/shares.nix`).
- **No identifying values in source.** This repo is public. Never write the world-facing domains, LAN IPs
  or similar identifiers literally: use `configVars.domain`, `configVars.homeDomain`,
  `configVars.networking.*` and friends (they come from the private `nix-secrets` input), and placeholders
  like `<domain>` in comments. The LAN-only `homeLanDomain` in `vars/` is the exception.
- **Neutral wording** for the owner's restricted content: the `datadat` tier is "limited-access"; `media`
  is the general-access group. Packages and third-party service modules describe their software neutrally,
  as if written for upstream nixpkgs.
- **Never create or edit secrets.** If a change needs a secret, name the sops key and any constraints on its
  value; the owner adds it by hand.

## Active Machines

**NixOS Systems**: pangolin11 (dev laptop), barliman (testbed), smeagol (GPU/Docker), durin (mini server), estel (media server), feanor (NAS), bombadil (VPS), droid (Android Virtualization Framework)
**Nix-Darwin**: macbookpro (work)
**Home Manager Only**: steamdeck, steammachine
**Archived**: bert, fedibox, william, thinkpadx1, melian, sauron, glorfindel, vm1 (in `hosts/archived/` and `home/tdoggett/archived/`)

### Machine Decision Matrix

| Machine | GUI | Power | RAM | Best For |
|---------|-----|-------|-----|----------|
| pangolin11 | ✓ | High | 32GB | Primary dev, testing new features |
| barliman | ✓ | High | 64GB (unified; GPU borrows up to 52GB) | Testbed, gaming, local LLMs |
| smeagol | ✓ | High | 32GB | GPU/AI workloads, Docker |
| durin | ✗ | Low | 8GB | Lightweight services |
| estel | ✗ | Med | 16GB | Media, 24/7 automation |
| feanor | ✗ | | | NAS, backups, services migrated from cirdan |
| bombadil | ✗ | Low | 4GB | **VPS - watch RAM!** Web services |
| macbookpro | ✓ | High | 16GB | Work (restrictions) |
| steamdeck | ✓ | Med | 16GB | Gaming (HM only, read-only) |
| steammachine | ✓ | Med | 16GB | Gaming (HM only, read-only) |

**Quick Guide**: Desktop features → pangolin11/barliman/smeagol/macbookpro | Heavy AI/video → smeagol/pangolin11/barliman | 24/7 services → durin/estel/feanor/bombadil

## Key Technologies

- **Nix Flakes** + **Home Manager** + **Nix-Darwin** (macOS)
- **SOPS** (secrets), **Lanzaboote** (Secure Boot), **Impermanence** (ephemeral root)
- **Stylix** (theming), **Arion** (Docker Compose)
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

# Check one option's value without building (system or Home Manager)
nix eval .#nixosConfigurations.<host>.config.<option.path>
nix eval .#nixosConfigurations.<host>.config.home-manager.users.<user>.<option.path>
nix eval .#darwinConfigurations.<host>.config.<option.path>   # work Mac; <host> is its name from nix-secrets (see `nix flake show`)

# Package sets (overlays in overlays/default.nix)
pkgs.packageName           # default: nixos-26.05
pkgs.stable.packageName    # nixos-26.05
pkgs.unstable.packageName  # nixos-unstable
pkgs.bleeding.packageName  # master branch
pkgs.old.packageName       # nixos-25.11
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

**Kanidm password/MFA reset link**: on feanor run `kanidm-reset <username> [seconds]` (defined in `hosts/common/optional/services/kanidm.nix`, which also documents the password-only vs MFA account policies)

## Important Notes

**Impermanence**: Several machines wipe root on boot. Only `/nix`, `/boot`, and explicitly persisted directories survive. Check `persistence.nix` files.

**Private repos**: `my-wordpress-plugins`, `my-sd-models`, `nix-secrets` require SSH auth on each machine.

**Archived systems**: Networking data in `nix-secrets` under `networking.archived.*`. Active systems may reference archived networking. Not actively maintained, expect build errors.

**Darwin-specific**: macbookpro uses Nix-Darwin, different module paths (`hosts/work/macbookpro/`).

**Multiple nixpkgs versions**: see "Package sets" above. The default is the stable release, not unstable.

## Bombadil Failover Certificate System

**Critical**: Failover certs MUST be in `/var/lib/acme-failover/`, NOT `/var/lib/acme/` (causes permission conflicts)

**How it works**: estel's `rsync-cert-sync` syncs certs to bombadil's `/var/lib/acme-failover/` → `rsync-cert-fix-permissions` fixes ownership → nginx uses them

**Config files**: `modules/nixos/rsync-cert-sync.nix`, `hosts/bombadil/nginx.nix`, `modules/nixos/failover-redirects.nix`

**Common issue**: ACME 403 errors → fix permissions: `sudo chown -R acme:nginx /var/lib/acme/acme-challenge/ && sudo chmod -R 755 /var/lib/acme/acme-challenge/`

## Commit Message Conventions

`flake:` inputs/structure | `pkgs:` custom packages | `modules:` custom modules | `hosts:` system configs | `home:` HM configs | `feat:` new features | `fix:` bugs | `refactor:` reorganization | `docs:` documentation
