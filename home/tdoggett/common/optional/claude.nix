{
  pkgs,
  config,
  lib,
  osConfig ? null,
  ...
}:
let
  cfg = config.myModules.claude;

  claudeMarkdown = ''
    # NixOS/Darwin-Nix Development Environment

    ## Tooling and Dependencies

    This environment uses Nix (either a NixOS or a Darwin-Nix system).
    When tools or dependencies are not available on the $PATH:

    - **Preferred approach**: Use `nix run` to execute tools directly from nixpkgs
      - Example: `nix run nixpkgs#python3 -- script.py`
      - Example: `nix run nixpkgs#nodejs -- app.js`

    - **Alternative approach**: Use `nix-shell` to create a temporary development environment
      - Example: `nix-shell -p python3 gcc` then run commands within the shell
      - Useful for iterative development with multiple tools

    - **Flake-based projects**: If a `flake.nix` exists, prefer entering the development shell
      - Example: `nix flake develop` or `nix develop`
      - This loads project-specific dependencies and environment setup

    ## Key Commands

    - `nix search nixpkgs <package>` - Find packages in nixpkgs
    - `nix run nixpkgs#<package> -- <command>` - Run a tool without installation
    - `nix-shell -p <packages>` - Temporary shell with specified packages
    - `nix develop` - Enter development environment from flake.nix
    - `which <command>` - Check if a tool is available before assuming it exists

    ## Assumptions

    Assume the system is a Nix-available machine unless proven otherwise.
    Avoid assuming standard system tools like `python`, `node`, `go`, etc. are globally
    available. Always check availability or use `nix run` to provide them.
  '';

  # These env vars are always enforced by Nix regardless of what Claude writes.
  # All other keys Claude adds (mcpServers, permissions, hooks, etc.) are preserved.
  baseSettings = {
    attribution = {
      commit = "";
      pr = "";
    };
    prefersReducedMotion = cfg.prefersReducedMotion;
    terminalProgressBarEnabled = cfg.terminalProgressBarEnabled;
    env = {
      # Disable nonessential UI features:
      CLAUDE_CODE_DISABLE_TERMINAL_TITLE = 1;
      CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = 1;
      # Disable auto-updates:
      DISABLE_AUTOUPDATER = 1;
      # Reduces splash screen size:
      IS_DEMO = 1;
      # Use system ripgrep instead of built-in version:
      USE_BUILTIN_RIPGREP = 0;
    }
    // lib.optionalAttrs cfg.disableTelemetry {
      CLAUDE_CODE_ENABLE_TELEMETRY = 0;
    }
    // lib.optionalAttrs cfg.disableNonessentialTraffic {
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = 1;
    }
    // lib.optionalAttrs cfg.fixAttributionHeaderForLocal {
      CLAUDE_CODE_ATTRIBUTION_HEADER = 0;
    };
  };

  baseSettingsJson = builtins.toJSON baseSettings;

  settingsFile = "${config.home.homeDirectory}/.claude/settings.json";
in
{
  options.myModules.claude = {
    fixAttributionHeaderForLocal = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set CLAUDE_CODE_ATTRIBUTION_HEADER=0. Disable on work machines where attribution headers are expected.";
    };
    disableTelemetry = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set CLAUDE_CODE_ENABLE_TELEMETRY=0 to disable telemetry reporting.";
    };
    disableNonessentialTraffic = lib.mkOption {
      type = lib.types.bool;
      default = if osConfig != null then (osConfig.services.ollama.enable or false) else false;
      description = "Set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1. Defaults to true when ollama is enabled.";
    };
    prefersReducedMotion = lib.mkOption {
      type = lib.types.bool;
      default = if osConfig != null then (osConfig.services.ollama.enable or false) else false;
      description = "Sets motion to be reduced. Defaults to true when ollama is enabled.";
    };
    terminalProgressBarEnabled = lib.mkOption {
      type = lib.types.bool;
      default = if osConfig != null then (!osConfig.services.ollama.enable or true) else true;
      description = "Enabled progress bar in terminal. Defaults to false when ollama is enabled.";
    };
  };

  # settings.json is managed via activation (not home.file) so Claude Code can write to it.
  # On each switch: Claude's additions are preserved, but the `env` section is always
  # overwritten with the Nix-defined base (merge strategy: base * existing * {env: base.env}).
  config = {
    home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.home.homeDirectory}/.claude"
      BASE='${baseSettingsJson}'

      if [ -L "${settingsFile}" ]; then
        # Remove old Nix-managed symlink from previous config approach
        rm "${settingsFile}"
      fi

      if [ -f "${settingsFile}" ]; then
        MERGED=$(${pkgs.jq}/bin/jq -n \
          --argjson base "$BASE" \
          --argjson existing "$(cat "${settingsFile}")" \
          '$base * $existing * {env: $base.env}')
        echo "$MERGED" > "${settingsFile}"
      else
        echo "$BASE" | ${pkgs.jq}/bin/jq '.' > "${settingsFile}"
      fi
    '';

    home.file."${config.home.homeDirectory}/.claude/CLAUDE.md".text = claudeMarkdown;
  };
}
