#################### DevShell ####################
#
# Custom shell for bootstrapping on new hosts, modifying nix-config, and secrets management

{
  pkgs ?
    # Fallback for plain `nix-shell shell.nix` (e.g. IDE integrations).
    # Resolves nixpkgs through the flake itself so it shares the flake's lock
    # and cache.  Cannot use `fetchTarball` with `lock.narHash` — the flake
    # hashes the filtered source tree, `fetchTarball` hashes the raw github
    # tarball, and the two will never agree.
    let
      flake = builtins.getFlake (toString ./.);
    in
    import flake.inputs.nixpkgs {
      overlays = [ ];
      system = builtins.currentSystem;
    },
  # Pre-commit check derivation from checks/default.nix — provides shellHook to install git hooks.
  # Defaults to a no-op when shell.nix is used standalone (without the flake).
  pre-commit-check ? {
    shellHook = "";
  },
  # System architecture (used to conditionally include Darwin-specific tools)
  system ? builtins.currentSystem,
  # darwin-rebuild from nix-darwin (only available when called from flake)
  darwin-rebuild ? null,
  ...
}:
let
  # Parallel per-machine eval. Discovers every nixos/darwin configuration from
  # the flake, spawns one `nix eval` per host (real parallelism — `nix eval`
  # itself is single-threaded), prints pass/FAIL live as each finishes, and
  # surfaces per-machine error output at the end so failures don't interleave.
  nix-config-eval-all = pkgs.writeShellApplication {
    name = "nix-config-eval-all";
    runtimeInputs = with pkgs; [
      nix
      coreutils
      gnugrep
    ];
    text = ''
      # Discover host names from the flake. `attrNames` is lazy on values so
      # this doesn't actually evaluate any machine config — just lists keys.
      mapfile -t NIXOS_HOSTS < <(
        nix eval --raw --apply 'cs: builtins.concatStringsSep "\n" (builtins.attrNames cs)' \
          .#nixosConfigurations 2>/dev/null || true
      )
      mapfile -t DARWIN_HOSTS < <(
        nix eval --raw --apply 'cs: builtins.concatStringsSep "\n" (builtins.attrNames cs)' \
          .#darwinConfigurations 2>/dev/null || true
      )

      declare -a LABELS=() ATTRS=()
      for h in "''${NIXOS_HOSTS[@]:-}"; do
        [ -z "$h" ] && continue
        LABELS+=("nixos/$h")
        ATTRS+=(".#nixosConfigurations.$h.config.system.build.toplevel")
      done
      for h in "''${DARWIN_HOSTS[@]:-}"; do
        [ -z "$h" ] && continue
        LABELS+=("darwin/$h")
        ATTRS+=(".#darwinConfigurations.$h.config.system.build.toplevel")
      done

      if [ "''${#LABELS[@]}" -eq 0 ]; then
        echo "ERROR: no configurations discovered. Are you at the flake root?" >&2
        exit 2
      fi

      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT INT TERM

      printf '==> Evaluating %d configurations in parallel...\n\n' "''${#LABELS[@]}"

      start_all=$(date +%s)

      for i in "''${!LABELS[@]}"; do
        (
          label="''${LABELS[i]}"
          attr="''${ATTRS[i]}"
          safe="''${label//\//_}"
          start=$(date +%s)
          if out=$(nix eval "$attr" --apply 'drv: drv.drvPath' 2>&1); then
            end=$(date +%s)
            printf '  %-4s  %-30s  (%ds)\n' OK "$label" "$((end-start))"
            printf 'PASS\t%s\n' "$label" >> "$tmp/summary"
          else
            end=$(date +%s)
            printf '  %-4s  %-30s  (%ds)\n' FAIL "$label" "$((end-start))"
            printf 'FAIL\t%s\n' "$label" >> "$tmp/summary"
            printf '%s\n' "$out" | grep -v '^warning: unknown setting' > "$tmp/$safe.err" || true
          fi
        ) &
      done

      wait

      end_all=$(date +%s)
      total=$((end_all - start_all))

      passed=$(grep -c '^PASS' "$tmp/summary" 2>/dev/null || true)
      failed=$(grep -c '^FAIL' "$tmp/summary" 2>/dev/null || true)
      passed="''${passed:-0}"
      failed="''${failed:-0}"

      printf '\n==> Done in %ds: %s passed, %s failed\n' "$total" "$passed" "$failed"

      if [ "$failed" -gt 0 ]; then
        printf '\n==> Failure details (each section is one machine)\n'
        while IFS=$'\t' read -r status label; do
          if [ "$status" = "FAIL" ]; then
            safe="''${label//\//_}"
            printf '\n---- %s ----\n' "$label"
            if [ -s "$tmp/$safe.err" ]; then
              cat "$tmp/$safe.err"
            else
              echo "(no captured stderr — rerun manually: nix eval .#$label.config.system.build.toplevel)"
            fi
          fi
        done < "$tmp/summary"
        exit 1
      fi
    '';
  };
in
{
  default = pkgs.mkShell {
    NIX_CONFIG = "extra-experimental-features = nix-command flakes";
    nativeBuildInputs =
      (builtins.attrValues {
        inherit (pkgs)
          # Required for pre-commit hook 'nixpkgs-fmt' only on Darwin
          # REF: <https://discourse.nixos.org/t/nix-shell-rust-hello-world-ld-linkage-issue/17381/4>
          libiconv

          nix
          nixd
          home-manager
          git
          jujutsu
          just
          pre-commit

          age
          ssh-to-age
          sops
          ;
      })
      ++ [ nix-config-eval-all ]
      # Add darwin-rebuild for Darwin systems (fallback for when /run/current-system is unavailable)
      ++ pkgs.lib.optionals (pkgs.stdenv.isDarwin && darwin-rebuild != null) [
        darwin-rebuild
        # Wrapper script to run darwin-rebuild with sudo while preserving PATH
        (pkgs.writeShellScriptBin "darwin-rebuild-sudo" ''
          sudo env PATH="${darwin-rebuild}/bin:$PATH" darwin-rebuild "$@"
        '')
      ];
    # Installs .git/hooks/pre-commit pointing to the Nix-managed hook script.
    # Running `nix develop` once per clone is all that's needed.
    shellHook = pre-commit-check.shellHook + ''
      # nix develop starts a fresh bash subshell that may not have inherited
      # SSH_AUTH_SOCK from the parent session's login profile (where home-manager
      # typically sets it to the gpg-agent SSH socket).  Without a working agent,
      # SSH agent forwarding to remote machines breaks — so we detect a valid
      # socket here and export it if needed.
      if [ ! -S "''${SSH_AUTH_SOCK:-}" ]; then
        for _sock in \
          "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gnupg/S.gpg-agent.ssh" \
          "$HOME/.gnupg/S.gpg-agent.ssh"; do
          if [ -S "$_sock" ]; then
            export SSH_AUTH_SOCK="$_sock"
            break
          fi
        done
        unset _sock
      fi

      # Per-repo jj fix.tools — kept local to .jj/repo/config.toml so other repos
      # aren't forced to use this repo's formatter conventions. Re-applied on every
      # nix develop so the store paths track the flake's nixpkgs.
      if command -v jj >/dev/null 2>&1 && [ -d .jj ]; then
        jj config set --repo "fix.tools.nixfmt.command" "[\"${pkgs.nixfmt}/bin/nixfmt\"]" >/dev/null
        jj config set --repo "fix.tools.nixfmt.patterns" "[\"glob:**/*.nix\"]" >/dev/null
        jj config set --repo "fix.tools.shfmt.command" "[\"${pkgs.shfmt}/bin/shfmt\", \"-ln\", \"auto\", \"-s\"]" >/dev/null
        jj config set --repo "fix.tools.shfmt.patterns" "[\"glob:**/*.sh\"]" >/dev/null
      fi
    '';
  };
}
