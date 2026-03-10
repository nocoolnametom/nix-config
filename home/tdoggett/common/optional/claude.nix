{
  pkgs,
  config,
  lib,
  osConfig ? null,
  ...
}:
let
  cfg = config.programs.claude;

  # Models available on the target ollama machine (from private my-sd-models flake)
  machineModels = lib.attrByPath [ cfg.ollamaMachine ] [ ] pkgs.my-sd-models.machineLLMs;

  # All three conditions must hold for local Claude to activate:
  #   1. useLocalClaude = true
  #   2. localModel is set (non-null)
  #   3. localModel is present in the target machine's model list
  localEnabled =
    cfg.useLocalClaude && cfg.localModel != null && builtins.elem cfg.localModel machineModels;

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
  }
  // lib.optionalAttrs localEnabled {
    # Skip the onboarding flow when using local ollama (no real API key needed)
    hasCompletedOnboarding = true;
    # Provide a dummy key as a fallback; the merge strategy preserves any real existing key
    primaryApiKey = "sk-dummy-key";
  }
  // {
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
    // lib.optionalAttrs (cfg.fixAttributionHeaderForLocal || localEnabled) {
      CLAUDE_CODE_ATTRIBUTION_HEADER = 0;
    }
    // lib.optionalAttrs localEnabled {
      ANTHROPIC_BASE_URL = "http://${cfg.ollamaHost}:${toString cfg.ollamaPort}";
      ANTHROPIC_API_KEY = "sk-1234";
    };
  };

  baseSettingsJson = builtins.toJSON baseSettings;

  settingsFile = "${config.home.homeDirectory}/.claude/settings.json";
in
{
  options.programs.claude = {
    enable = lib.mkEnableOption "Claude Code settings management";
    fixAttributionHeaderForLocal = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Set CLAUDE_CODE_ATTRIBUTION_HEADER=0. Automatically forced when useLocalClaude is active; set this explicitly only if you want it forced without local Claude.";
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
    useLocalClaude = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use a local ollama instance instead of the Anthropic API. Also requires localModel to be set and available on ollamaMachine.";
    };
    localModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Ollama model name (e.g. \"llama3.2:latest\"). Must match an entry in pkgs.my-sd-models.machineLLMs for ollamaMachine. If null, local Claude is disabled regardless of useLocalClaude.";
    };
    ollamaHost = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "Host or IP address of the machine running ollama. Used to build ANTHROPIC_BASE_URL. For remote machines (e.g. estel → barliman), set this to the remote IP/hostname.";
    };
    ollamaPort = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Port ollama is listening on. Used to build ANTHROPIC_BASE_URL.";
    };
    ollamaMachine = lib.mkOption {
      type = lib.types.str;
      default = if osConfig != null then (osConfig.networking.hostName or "") else "";
      description = "Hostname key used to look up available models in pkgs.my-sd-models.machineLLMs. Defaults to the current machine. Override when pointing at a remote ollama host (e.g. set to \"barliman\" on estel).";
    };
  };

  # settings.json is managed via activation (not home.file) so Claude Code can write to it.
  # On each switch: Claude's additions are preserved, but the `env` section is always
  # overwritten with the Nix-defined base (merge strategy: base * existing * {env: base.env}).
  # When localEnabled, hasCompletedOnboarding is also forced from base.
  # primaryApiKey uses base as a fallback only — any existing key is preserved by the merge.
  config = lib.mkIf cfg.enable {
    warnings =
      lib.optionals
        (cfg.useLocalClaude && cfg.localModel != null && !(builtins.elem cfg.localModel machineModels))
        [
          "programs.claude: localModel '${cfg.localModel}' was not found in pkgs.my-sd-models.machineLLMs for machine '${cfg.ollamaMachine}'. Local Claude will not be configured."
        ];

    # When local Claude is active, alias `claude` to always pass --model so the user
    # only needs to write `claude --other-flags` without specifying the model each time.
    home.shellAliases = lib.mkIf localEnabled {
      claude = "claude --model ${lib.escapeShellArg cfg.localModel}";
    };

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
          '$base * $existing * {env: $base.env${lib.optionalString localEnabled ", hasCompletedOnboarding: $base.hasCompletedOnboarding"}}')
        echo "$MERGED" > "${settingsFile}"
      else
        echo "$BASE" | ${pkgs.jq}/bin/jq '.' > "${settingsFile}"
      fi
    '';

    home.file."${config.home.homeDirectory}/.claude/CLAUDE.md".text = claudeMarkdown;
  };
}
