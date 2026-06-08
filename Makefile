###############################################################################
#
#  nix-config — local checks
#
#  Run these manually before `jj git push` since jj 0.41 does not invoke
#  git's pre-push hook (see home/tdoggett/common/optional/jj.nix).
#
#  Targets shell out via `nix develop -c` so they pick up the correct
#  pre-commit version and the generated .pre-commit-config.yaml from the
#  devShell, even when invoked from outside it.
#
###############################################################################

.DEFAULT_GOAL := help
.NOTPARALLEL:   check

.PHONY: help check check-fast check-eval fmt

# Auto-derive the per-system `eval-*` hook IDs so `check-fast`/`check` skip
# the serial pre-commit eval-* hooks (we run them in parallel via
# nix-config-eval-all instead). Tracks added/removed hosts automatically.
# Empty if .pre-commit-config.yaml hasn't been generated yet (run `nix develop`
# once to create it).
SLOW_HOOKS := $(shell grep -oE '"eval-[A-Za-z0-9-]+"' .pre-commit-config.yaml 2>/dev/null | tr -d '"' | sort -u | paste -sd, -)

help:
	@echo "nix-config — local checks (run before 'jj git push')"
	@echo ""
	@echo "  make check       Format/lint + per-system nix eval (parallel)"
	@echo "  make check-fast  Format/lint only — skip the slow per-system eval"
	@echo "  make check-eval  Per-system nix eval only (parallel; clear failures)"
	@echo "  make fmt         Auto-format .nix (nixfmt) and shell (shfmt) files"

# Full validation: format/lint first (fast, fails early on format issues),
# then parallel per-machine eval. `.NOTPARALLEL` above keeps make from
# trying to interleave them with `make -jN`.
check: check-fast check-eval

check-fast:
	SKIP="$(SLOW_HOOKS)" nix develop -c pre-commit run --hook-stage pre-push --all-files

# Parallel eval of every nixos + darwin configuration. See shell.nix
# (`nix-config-eval-all`) for the runner.
check-eval:
	nix develop -c nix-config-eval-all

fmt:
	nix fmt -- .
	-nix develop -c pre-commit run --hook-stage pre-push --all-files shfmt
