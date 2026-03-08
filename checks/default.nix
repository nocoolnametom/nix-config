{
  inputs,
  pkgs,
  system,
  # Active system names from flake outputs, used to generate one pre-push hook per system.
  # Defaults to empty so checks/ can still be imported standalone without the flake context.
  # HM configs are excluded: their keys use dynamic nix-secrets references that can break
  # flake evaluation if those attrs are missing. NixOS keys are static; Darwin is safe too.
  nixosNames ? [ ],
  darwinNames ? [ ],
  ...
}:
let
  # Create one pre-push hook that evaluates a single config's drvPath.
  # On success: exits 0, pre-commit prints "Passed" for this hook's line.
  # On failure: prints filtered error output and exits 1 (or 0 for warn-only).
  # Filtering drops Determinate Nix "unknown setting" warnings that are pure noise.
  mkEvalHook =
    {
      hookKey, # Used as the Nix attribute key and the generated script's filename
      displayName, # Shown in pre-commit's progress line (e.g. "eval nixos/pangolin11")
      attr, # Flake installable to evaluate (must produce a derivation)
    }:
    {
      enable = true;
      name = displayName;
      description = "Evaluate ${displayName} before push";
      language = "system";
      entry = toString (
        pkgs.writeShellScript hookKey ''
          if result=$(nix eval '${attr}' --apply 'drv: drv.drvPath' 2>&1); then
            true
          else
            printf "%s\n" "$result" | grep -v "^warning: unknown setting" >&2
            exit 1
          fi
        ''
      );
      stages = [ "pre-push" ];
      pass_filenames = false;
      files = "\\.nix$";
    };

  # Sanitize a string for use as a Nix attribute key / shell script filename.
  sanitize = builtins.replaceStrings [ "@" "." " " "/" ] [ "-at-" "-" "-" "-" ];

  nixosHooks = builtins.listToAttrs (
    map (name: {
      name = "eval-nixos-${name}";
      value = mkEvalHook {
        hookKey = "eval-nixos-${name}";
        displayName = "eval nixos/${name}";
        attr = ".#nixosConfigurations.${name}.config.system.build.toplevel";
      };
    }) nixosNames
  );

  darwinHooks = builtins.listToAttrs (
    map (name: {
      name = "eval-darwin-${sanitize name}";
      value = mkEvalHook {
        hookKey = "eval-darwin-${sanitize name}";
        displayName = "eval darwin/${name}";
        attr = ".#darwinConfigurations.${name}.config.system.build.toplevel";
      };
    }) darwinNames
  );

in
{
  pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
    src = builtins.path {
      path = ./.;
      name = "pre-commit-check-source";
    };
    default_stages = [ "pre-commit" ];
    hooks = {
      # ========== General ==========
      check-added-large-files.enable = true;
      check-case-conflicts.enable = true;
      check-executables-have-shebangs.enable = true;
      check-shebang-scripts-are-executable.enable = true;
      check-merge-conflicts.enable = true;
      detect-private-keys.enable = true;
      fix-byte-order-marker.enable = true;
      mixed-line-endings.enable = true;
      trim-trailing-whitespace.enable = true;

      forbid-submodules = {
        enable = true;
        name = "forbid submodules";
        description = "forbids any submodules in the repository";
        language = "fail";
        entry = "submodules are not allowed in this repository:";
        types = [ "directory" ];
      };

      destroyed-symlinks = {
        enable = true;
        name = "destroyed-symlinks";
        description = "detects symlinks which are changed to regular files with a content of a path which that symlink was pointing to.";
        package = inputs.pre-commit-hooks.checks.${system}.pre-commit-hooks;
        entry = "${inputs.pre-commit-hooks.checks.${system}.pre-commit-hooks}/bin/destroyed-symlinks";
        types = [ "symlink" ];
      };

      # ========== nix ==========
      nixfmt-rfc-style.enable = true;

      # ========== shellscripts ==========
      shfmt.enable = true;

      end-of-file-fixer.enable = true;

      # ========== pre-push: per-system nix evaluation ==========
      # Individual hooks for each active system are merged in below.
      # Each produces its own "Passed/Failed" line in the pre-commit output.
      # Archived and HM-only systems are intentionally excluded.
      # Archived: not actively maintained.
      # HM-only (vm1, steamdeck): config keys use dynamic nix-secrets refs that can
      # cause flake evaluation failures if those attrs are missing from nix-secrets.
    }
    // nixosHooks
    // darwinHooks;
  };
}
