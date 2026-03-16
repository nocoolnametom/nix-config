{
  pkgs,
  config,
  lib,
  configVars,
  osConfig ? null,
  ...
}:
let
  cfg = config.programs.claude;

  # The hostname key used for machineLLMs lookup:
  # - null ollamaMachine → current machine's hostName
  # - set ollamaMachine  → that machine's name (validated enum)
  llmsMachineKey =
    if cfg.ollamaMachine != null then
      cfg.ollamaMachine
    else if osConfig != null then
      (osConfig.networking.hostName or "")
    else
      "";

  # Models available on the target ollama machine (from private my-sd-models flake)
  machineModels = lib.attrByPath [ llmsMachineKey ] [ ] pkgs.my-sd-models.machineLLMs;

  # Effective model: explicit localModel takes priority; otherwise fall back to the
  # primary coding model declared for the target machine in machinePrimaryLLMs.
  # This avoids duplicating the model string across every satellite home config.
  effectiveLocalModel =
    if cfg.localModel != null then
      cfg.localModel
    else
      let
        primaryLLMs = lib.attrByPath [ llmsMachineKey ] { } pkgs.my-sd-models.machinePrimaryLLMs;
      in
      primaryLLMs.coding or null;

  # When machineModels is non-empty we can validate the model against the known list.
  # When it's empty (custom endpoint, or a machine with no machineLLMs entry) there's
  # nothing to validate against, so we trust the explicit model and skip the check.
  modelIsValid = machineModels == [ ] || builtins.elem effectiveLocalModel machineModels;

  # All conditions must hold for local Claude to activate:
  #   1. useLocalClaude = true
  #   2. effectiveLocalModel is non-null
  #   3. model is either valid against machineLLMs or unverifiable (custom endpoint)
  localEnabled = cfg.useLocalClaude && effectiveLocalModel != null && modelIsValid;

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

  # Common settings applied to both regular and local claude
  # These env vars are always enforced by Nix regardless of what Claude writes.
  # All other keys Claude adds (mcpServers, permissions, hooks, etc.) are preserved.
  commonSettings = {
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

  # Settings specific to local ollama usage
  # These are merged with commonSettings to create the local settings file
  localOnlyEnv = {
    CLAUDE_CODE_ATTRIBUTION_HEADER = 0;
    ANTHROPIC_BASE_URL = "http://${cfg.ollamaHost}:${toString cfg.ollamaPort}";
    ANTHROPIC_API_KEY = "sk-1234";
    API_TIMEOUT_MS = "3000000";
    ANTHROPIC_MODEL = "${effectiveLocalModel}";
    ANTHROPIC_SMALL_FAST_MODEL = "${effectiveLocalModel}";
    ANTHROPIC_DEFAULT_SONNECT_MODEL = "${effectiveLocalModel}";
    ANTHROPIC_DEFAULT_OPUS_MODEL = "${effectiveLocalModel}";
    ANTHROPIC_DEFAULT_HAIKU_MODEL = "${effectiveLocalModel}";
  };

  # Full local settings (common + local-only)
  localSettings = commonSettings // {
    # Skip the onboarding flow when using local ollama (no real API key needed)
    hasCompletedOnboarding = true;
    # Merge common env with local-only env
    # Note: ANTHROPIC_API_KEY is set in localOnlyEnv, no need for primaryApiKey here
    env = commonSettings.env // localOnlyEnv;
  };

  commonSettingsJson = builtins.toJSON commonSettings;
  localSettingsJson = builtins.toJSON localSettings;

  settingsFile = "${config.home.homeDirectory}/.claude/settings.json";
  localSettingsFile = "${config.home.homeDirectory}/.claude/settings-local.json";
in
{
  options.programs.claude = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Claude Code settings management";
    };
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
      default = effectiveLocalModel != null && modelIsValid;
      defaultText = lib.literalExpression "effectiveLocalModel != null && (machineModels is empty or effectiveLocalModel is in machineModels)";
      description = "Use a local ollama instance instead of the Anthropic API. Defaults to true when a model is available and either confirmed against machineLLMs or using a custom endpoint with no list to validate against.";
    };
    localModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Ollama model name (e.g. \"llama3.2:latest\"). Must match an entry in pkgs.my-sd-models.machineLLMs for ollamaMachine. If null, local Claude is disabled regardless of useLocalClaude.";
    };
    ollamaMachine = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum (builtins.attrNames configVars.networking.subnets));
      default = null;
      description = "Subnet machine name running ollama. Null means localhost (current machine). When set, ollamaHost defaults to that machine's LAN IP from configVars.networking.subnets.";
    };
    ollamaHost = lib.mkOption {
      type = lib.types.str;
      default =
        if cfg.ollamaMachine != null then
          configVars.networking.subnets.${cfg.ollamaMachine}.ip
        else
          "localhost";
      defaultText = lib.literalExpression "configVars.networking.subnets.<ollamaMachine>.ip, or \"localhost\" when ollamaMachine is null";
      description = "Host or IP address of the machine running ollama. Defaults to the LAN IP of ollamaMachine, or localhost when ollamaMachine is null.";
    };
    ollamaPort = lib.mkOption {
      type = lib.types.port;
      default = configVars.networking.ports.tcp.ollama;
      description = "Port ollama is listening on. Defaults to configVars.networking.ports.tcp.ollama.";
    };
  };

  # Regular settings.json is managed via activation (not home.file) so Claude Code can write to it.
  # On each switch: Claude's additions are preserved, but the `env` section is always
  # overwritten with the Nix-defined common settings (merge strategy: common * existing * {env: common.env}).
  # The regular settings file is kept clean and never contains local-management keys.
  #
  # When local mode is enabled, a separate immutable settings-local.json is created with
  # all local-specific settings, and a `claude-local` wrapper command is provided.
  config = lib.mkIf cfg.enable {
    warnings =
      lib.optionals
        (cfg.localModel != null && machineModels != [ ] && !(builtins.elem cfg.localModel machineModels))
        [
          "programs.claude: localModel '${cfg.localModel}' was not found in pkgs.my-sd-models.machineLLMs for machine '${llmsMachineKey}'. Local Claude will not be configured."
        ];

    # Install claude-code; when local mode is active also provide a `claude-local` wrapper
    # that points at the local settings file (which overrides the API endpoint + model).
    home.packages = [
      pkgs.claude-code
    ]
    ++ lib.optionals localEnabled [
      (pkgs.writeShellScriptBin "claude-local" ''
        exec ${pkgs.claude-code}/bin/claude --settings "${localSettingsFile}" "$@"
      '')
    ];

    # Regular settings file - mutable, contains common settings only
    home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${config.home.homeDirectory}/.claude"
      BASE='${commonSettingsJson}'

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

    # Local settings file - immutable, contains all settings including local-management keys
    # Only created when local mode is enabled
    home.file.".claude/settings-local.json" = lib.mkIf localEnabled {
      text = localSettingsJson;
    };

    home.file."${config.home.homeDirectory}/.claude/CLAUDE.md".text = claudeMarkdown;
  };
}
