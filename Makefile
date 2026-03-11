###############################################################################
#
#  nix-config deployment Makefile
#
#  Builds and deploys NixOS / nix-darwin / Home Manager configurations from
#  the local checkout to each machine.  All build targets use `nix run` to
#  pull the required tools on-demand so the Makefile works from any host
#  (including macOS) without needing them pre-installed.
#
#  Useful workflows:
#    make update-estel   # pull latest repo on estel, then
#    make estel          # build from local repo and switch estel
#
#    make update-all     # pull latest on every machine
#    make all            # build + switch every machine (sequential)
#    make -j4 all        # build + switch every machine (parallelised, use with care)
#
###############################################################################

##─────────────────────────────────────────────────────────────────────────────
## SSH targets
## Machines on the local LAN are reachable at <hostname>.doggett.home.
## Adjust BOMBADIL to the actual VPS hostname/IP.
## If estel needs a ProxyJump through bombadil, add a ~/.ssh/config entry rather
## than encoding it here, and keep ESTEL as just the hostname.
##─────────────────────────────────────────────────────────────────────────────

USER        := tdoggett
LAN_DOMAIN  := doggett.home

PANGOLIN11  := $(USER)@pangolin11.$(LAN_DOMAIN)
BARLIMAN    := $(USER)@barliman.$(LAN_DOMAIN)
SMEAGOL     := $(USER)@smeagol.$(LAN_DOMAIN)
DURIN       := $(USER)@durin.$(LAN_DOMAIN)
ESTEL       := $(USER)@estel.$(LAN_DOMAIN)   # ProxyJump via bombadil if needed — configure in ~/.ssh/config
BOMBADIL    := $(USER)@bombadil               # TODO: set to actual VPS address (in nix-secrets)
STEAMDECK   := deck@steamdeck.$(LAN_DOMAIN)

## Path to this repo on remote machines (used by update-* targets)
REMOTE_REPO := ~/Projects/nocoolnametom/nix-config

##─────────────────────────────────────────────────────────────────────────────
## Build tools
## nixos-rebuild is not available by default on macOS, so we use `nix run`
## to pull it from nixpkgs on demand.  This also works fine on NixOS.
## darwin-rebuild is provided by nix-darwin and expected to be in PATH on macOS.
## home-manager is used for HM-only targets and also pulled via `nix run`.
##─────────────────────────────────────────────────────────────────────────────

NIXOS_REBUILD   := nix run nixpkgs\#nixos-rebuild --
HOME_MANAGER    := nix run nixpkgs\#home-manager --

##─────────────────────────────────────────────────────────────────────────────
## Default goal: show help
##─────────────────────────────────────────────────────────────────────────────

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "nix-config deployment targets"
	@echo ""
	@echo "  Update (git pull --rebase on remote):"
	@echo "    make update-pangolin11   make update-barliman   make update-smeagol"
	@echo "    make update-estel        make update-bombadil   make update-durin"
	@echo "    make update-steamdeck    make update-macbookpro (local pull)"
	@echo "    make update-all          (all of the above)"
	@echo ""
	@echo "  Build & switch (from this local repo):"
	@echo "    make pangolin11   make barliman   make smeagol"
	@echo "    make estel        make bombadil   make durin"
	@echo "    make steamdeck    make macbookpro (local darwin-rebuild)"
	@echo "    make all          (all of the above, sequential)"
	@echo "    make -j4 all      (parallel — use with care on slow machines)"

##─────────────────────────────────────────────────────────────────────────────
## update-* targets: git pull --rebase on the remote machine
## Agent forwarding is handled by ForwardAgent yes in the "Host *" block in
## home/tdoggett/common/core/ssh.nix — no -A flag needed here.
##─────────────────────────────────────────────────────────────────────────────

.PHONY: update-pangolin11
update-pangolin11:
	ssh $(PANGOLIN11) 'git -C $(REMOTE_REPO) pull --rebase'

.PHONY: update-barliman
update-barliman:
	ssh $(BARLIMAN) 'git -C $(REMOTE_REPO) pull --rebase'

.PHONY: update-smeagol
update-smeagol:
	ssh $(SMEAGOL) 'git -C $(REMOTE_REPO) pull --rebase'

.PHONY: update-estel
update-estel:
	ssh $(ESTEL) 'git -C $(REMOTE_REPO) pull --rebase'

.PHONY: update-bombadil
update-bombadil:
	ssh $(BOMBADIL) 'git -C $(REMOTE_REPO) pull --rebase'

.PHONY: update-durin
update-durin:
	ssh $(DURIN) 'git -C $(REMOTE_REPO) pull --rebase'

.PHONY: update-steamdeck
update-steamdeck:
	ssh $(STEAMDECK) 'git -C $(REMOTE_REPO) pull --rebase'

.PHONY: update-macbookpro
update-macbookpro:
	git pull --rebase

.PHONY: update-all
update-all: update-pangolin11 update-barliman update-smeagol update-estel \
            update-bombadil update-durin update-steamdeck update-macbookpro

##─────────────────────────────────────────────────────────────────────────────
## Build & switch targets
##
## NixOS targets evaluate the flake locally and copy the built closure to the
## target host via SSH, then activate it there.  Requires `--use-remote-sudo`
## since we SSH as $(USER) (wheel, passwordless sudo).
##
## When running from aarch64-darwin (macbookpro), cross-architecture builds
## are offloaded to the remote builders configured in nix-remote-builders.nix.
##─────────────────────────────────────────────────────────────────────────────

.PHONY: pangolin11
pangolin11:
	$(NIXOS_REBUILD) switch --flake .#pangolin11 \
	  --target-host $(PANGOLIN11) \
	  --use-remote-sudo

.PHONY: barliman
barliman:
	$(NIXOS_REBUILD) switch --flake .#barliman \
	  --target-host $(BARLIMAN) \
	  --use-remote-sudo

.PHONY: smeagol
smeagol:
	$(NIXOS_REBUILD) switch --flake .#smeagol \
	  --target-host $(SMEAGOL) \
	  --use-remote-sudo

.PHONY: estel
estel:
	$(NIXOS_REBUILD) switch --flake .#estel \
	  --target-host $(ESTEL) \
	  --use-remote-sudo

.PHONY: bombadil
bombadil:
	$(NIXOS_REBUILD) switch --flake .#bombadil \
	  --target-host $(BOMBADIL) \
	  --use-remote-sudo

.PHONY: durin
durin:
	$(NIXOS_REBUILD) switch --flake .#durin \
	  --target-host $(DURIN) \
	  --use-remote-sudo

## macOS — run darwin-rebuild locally (this IS the macbookpro).
## darwin-rebuild is provided by nix-darwin and should be in PATH.
.PHONY: macbookpro
macbookpro:
	darwin-rebuild switch --flake .#macbookpro

## Steam Deck — HM-only, must be built and activated on the deck itself.
## We SSH in and run home-manager against the remote repo (pull first with
## update-steamdeck if you need the latest changes there).
.PHONY: steamdeck
steamdeck:
	ssh $(STEAMDECK) \
	  'nix run nixpkgs\#home-manager -- switch --flake $(REMOTE_REPO)\#deck@steamdeck'

.PHONY: all
all: pangolin11 barliman smeagol estel bombadil durin macbookpro steamdeck
