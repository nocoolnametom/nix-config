# EmergentMind nix-config Comparison

**Date**: 2026-03-08
**EmergentMind Repo**: https://github.com/EmergentMind/nix-config
**Reference commit**: Latest dev branch as of 2026-03-08

## Overview

EmergentMind's nix-config is an educational/experimental configuration (uses `dev` as default branch) while ours is production-focused (stable `main` branch). This document tracks features from their config that could benefit our setup.

## Features Already Adopted ✅

### GPU Monitoring Tools (2026-03-08)
- **nvtop**: Multi-GPU monitoring (NVIDIA, AMD, Intel) - Added to smeagol, barliman, pangolin11
- **amdgpu_top**: AMD-specific GPU monitoring - Added to barliman
- **plymouth**: Enhanced boot splash with animated themes from adi1090x - Upgraded existing module

## Features We Already Have ✅

- **Ollama**: Our implementation is MORE comprehensive (extensive model list, better config)
- **YubiKey**: Nearly identical functionality, ours has SSH agent auth
- **Core/Optional separation**: Both use same pattern
- **SOPS secrets**: Both use same approach
- **Impermanence**: Both use same approach
- **Multi-host flakes**: Both support multiple machines

## High-Priority Features to Consider

### 1. Disko Integration
**Status**: Not yet evaluated
**Benefit**: Declarative disk partitioning and formatting
**Effort**: Medium-High (requires refactoring disk configs)
**Impact**: Improves reproducibility, simplifies bootstrapping
**Notes**: Would be useful for new machine setup and disaster recovery

### 2. YubiKey Auto-Lock/Unlock
**Status**: Code exists but commented out in our config
**Benefit**: Lock screen on YubiKey removal, unlock on insertion
**Effort**: Low (just enable options)
**Impact**: Security improvement for laptops
**Best for**: pangolin11, macbookpro
**Notes**: Our module already has the code, just needs options added like EmergentMind's

### 3. Automated Bootstrapping Scripts
**Status**: Not yet evaluated
**Benefit**: Automate remote NixOS installation and setup
**Effort**: Medium
**Impact**: Simplifies new machine deployment
**Notes**: Useful for "future systems" planning mentioned in CLAUDE.md

## Medium-Priority Features

### 4. Niri Compositor with UWSM
**Status**: We have niri, but not UWSM integration
**Benefit**: Universal Wayland Session Manager for better compositor management
**Effort**: Low-Medium
**Impact**: Improved Wayland session handling
**Best for**: Desktop machines (pangolin11, barliman)
**Notes**: Recently added to EmergentMind (Feb 2026)

### 5. Scanning Support Module
**Status**: Not implemented
**Benefit**: Document scanning support
**Effort**: Low (simple module)
**Impact**: Useful for desktop machines
**Best for**: pangolin11, barliman

### 6. Obsidian Module
**Status**: Not implemented
**Benefit**: Knowledge management tool
**Effort**: Very low (one-line package install)
**Impact**: Useful for documentation and note-taking
**Best for**: pangolin11, macbookpro

## Low-Priority or Not Applicable

### LUKS Integration
- EmergentMind uses YubiKey for LUKS decryption
- We use Lanzaboote/Secure Boot instead
- **Decision**: Different approach, not needed

### Borg Backup
- EmergentMind has refined Borg backup configs
- We don't currently use Borg
- **Decision**: Evaluate if needed in future

### Multiple nixpkgs Versions
- **Status**: We already have this! (stable, unstable, master, old)
- Our implementation: `pkgs.stable.*`, `pkgs.unstable.*`, `pkgs.bleeding.*`, `pkgs-old.*`
- EmergentMind has similar approach

## Testing Strategy

When adopting features:

1. **Test on dev branch first** (this branch)
2. **Use testbed machines**: barliman (primary testbed), pangolin11 (secondary)
3. **Avoid breaking production**: estel, durin, bombadil, smeagol should get stable features
4. **Watch RAM on bombadil**: VPS with only 4GB, be cautious with new services

## Recent EmergentMind Changes (Feb-Mar 2026)

- Ollama integration (we already have this, ours is better)
- Niri via UWSM (could adopt)
- Avante Neovim plugin (AI code assistant)
- Disk declaration overhaul (Disko improvements)
- Impermanence redesign
- "Escaped the nixvim trap" - moved away from NixVim framework
- NFS timeout/automount improvements
- Borg backup refinements

## Action Items

- [ ] Evaluate Disko for future machine deployments
- [ ] Add autoScreenLock/autoScreenUnlock options to YubiKey module
- [ ] Create scanning support module for desktop machines
- [ ] Investigate UWSM for Niri compositor
- [ ] Review their NFS improvements for our network shares
- [ ] Consider Obsidian for pangolin11/macbookpro
- [ ] Explore their bootstrapping scripts for inspiration

## Philosophy Differences

| Aspect | Our Config | EmergentMind |
|--------|-----------|--------------|
| Branch | main (stable) | dev (experimental) |
| Focus | Production | Educational |
| Platforms | NixOS + Darwin + HM-only | NixOS + HM (Darwin deprecated) |
| Updates | Careful with rollback strategy | Experimental, embraces breakage |
| Documentation | Production-focused | Learning-oriented |

## Conclusion

EmergentMind's config offers some interesting features, but we already have most of the important ones. The highest-value additions are:

1. GPU monitoring tools ✅ (already adopted)
2. Enhanced plymouth themes ✅ (already adopted)
3. YubiKey auto-lock options (low-hanging fruit)
4. Disko integration (if we want better provisioning)
5. Scanning support (desktop convenience)

Our config is more production-ready with better multi-platform support, while theirs is more experimental and educational. Both approaches have merit depending on goals.
