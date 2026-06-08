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

.PHONY: help check check-fast fmt

# Auto-derive the per-system `eval-*` hook IDs that `check-fast` skips, so
# adding/removing hosts in checks/default.nix is reflected here automatically.
# Empty if .pre-commit-config.yaml hasn't been generated yet (run `nix develop`
# once to create it).
SLOW_HOOKS := $(shell grep -oE '"eval-[A-Za-z0-9-]+"' .pre-commit-config.yaml 2>/dev/null | tr -d '"' | sort -u | paste -sd, -)

help:
	@echo "nix-config — local checks (run before 'jj git push')"
	@echo ""
	@echo "  make check       Run all pre-push hooks (format/lint + per-system eval)"
	@echo "  make check-fast  Format/lint only — skip the slow per-system eval"
	@echo "  make fmt         Auto-format .nix (nixfmt) and shell (shfmt) files"

check:
	nix develop -c pre-commit run --hook-stage pre-push --all-files

check-fast:
	SKIP="$(SLOW_HOOKS)" nix develop -c pre-commit run --hook-stage pre-push --all-files

fmt:
	nix fmt -- .
	-nix develop -c pre-commit run --hook-stage pre-push --all-files shfmt
