{
  pkgs,
  config,
  lib,
  ...
}:
let
  jsonFormat = pkgs.formats.json { };
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
in
{
  home.file."${config.home.homeDirectory}/.claude/settings.json".source =
    jsonFormat.generate "claude-settings-${config.home.username}"
      {
        # Disable telemetry and nonessential features:
        env.CLAUDE_CODE_DISABLE_TERMINAL_TITLE = 1;
        env.CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = 1;
        env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = 1;
        # Disable auto-updates:
        env.DISABLE_AUTOUPDATER = 1;
        # reduces splash screen size:
        env.IS_DEMO = 1;
        # Use system ripgrep instead of built-in version:
        env.USE_BUILTIN_RIPGREP = 0;
      };

  home.file."${config.home.homeDirectory}/.claude/CLAUDE.md".text = claudeMarkdown;
}
