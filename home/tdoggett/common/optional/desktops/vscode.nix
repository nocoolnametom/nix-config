{ pkgs, lib, ... }:
{
  programs.vscode = {
    enable = lib.mkDefault true;
    # 2026-11-06: take the package from nixos-unstable, not the default (stable) set.
    # nixos-26.05 backported VS Code 1.144.0 (nixpkgs PR #580502) without the matching
    # generic.nix change, so its patchPhase still deletes
    # resources/app/node_modules/@vscode/ripgrep/bin/rg, which moved to
    # @vscode/ripgrep-universal/bin/<platform>/rg in 1.122.0. The stable build therefore
    # fails with "rm: cannot remove ...ripgrep/bin/rg: No such file or directory".
    # The unstable recipe handles both layouts. VS Code is unfree, so Hydra never puts it
    # in cache.nixos.org; every host downloads and patches it locally whichever set we use,
    # so this costs nothing extra. Revisit once stable's generic.nix catches up.
    package = lib.mkDefault pkgs.unstable.vscode;
    mutableExtensionsDir = lib.mkDefault true;
    profiles.default = {
      enableUpdateCheck = lib.mkDefault false;
      extensions = with pkgs.vscode-extensions; [
        vscodevim.vim
        ms-vscode-remote.remote-ssh
        redhat.vscode-yaml
        github.copilot
        jnoortheen.nix-ide
        christian-kohler.path-intellisense
        codezombiech.gitignore
        signageos.signageos-vscode-sops
        eamodio.gitlens
      ];
      userSettings = {
        "diffEditor.ignoreTrimWhitespace" = false;
        "editor.fontLigatures" = true;
        "editor.inlineSuggest.enabled" = true;
        "editor.minimap.autohide" = "scroll";
        "editor.minimap.enabled" = true;
        "editor.minimap.renderCharacters" = false;
        "editor.minimap.scale" = 1;
        "editor.renderWhitespace" = "trailing";
        "editor.stickyScroll.enabled" = true;
        "editor.suggest.preview" = true;
        "files.autoSave" = "onWindowChange";
        "files.autoSaveWhenNoErrors" = true;
        "git.autofetch" = true;
        "javascript.inlayHints.enumMemberValues.enabled" = true;
        "javascript.inlayHints.functionLikeReturnTypes.enabled" = true;
        "javascript.inlayHints.parameterNames.enabled" = "all";
        "javascript.inlayHints.parameterTypes.enabled" = true;
        "javascript.inlayHints.propertyDeclarationTypes.enabled" = true;
        "javascript.inlayHints.variableTypes.enabled" = true;
        "redhat.telemetry.enabled" = false;
        "telemetry.telemetryLevel" = "error";
        "typescript.inlayHints.enumMemberValues.enabled" = true;
        "typescript.inlayHints.functionLikeReturnTypes.enabled" = true;
        "typescript.inlayHints.parameterNames.enabled" = "all";
        "typescript.inlayHints.parameterTypes.enabled" = true;
        "typescript.inlayHints.propertyDeclarationTypes.enabled" = true;
        "typescript.inlayHints.variableTypes.enabled" = true;
        "update.mode" = "none";
        "window.titleBarStyle" = "custom";
        "workbench.activityBar.location" = "top";
        "workbench.editor.pinnedTabsOnSeparateRow" = true;
        "workbench.editor.wrapTabs" = true;
        "chat.tools.terminal.autoApprove" = {
          "sudo nix-store" = true;
          "nix-store" = true;
          "true" = true;
          "cp" = true;
          "mv" = true;
          "wc" = true;
          "ls" = true;
          "cat" = true;
          "echo" = true;
          "pwd" = true;
          "cd" = true;
          "touch" = true;
          "mkdir" = true;
          "rm" = true;
          "rmdir" = true;
          "sort" = true;
          "tail" = true;
          "head" = true;
          "find" = true;
          "grep" = true;
          "date" = true;
          "whoami" = true;
          "df" = true;
          "du" = true;
          "uptime" = true;
          "nix" = true;
          "nix-prefetch-url" = true;
          "sed" = true;
        };
        "chat.agent.maxRequests" = 300;
        "chat.allowAnonymousAccess" = true;
        "chat.customAgentInSubagent.enabled" = true;
        "chat.editing.confirmEditRequestRemoval" = false;
        "mcp.servers.my-mcp-server.type" = "playwright";
        "mcp.servers.my-mcp-server.command" = "${pkgs.nodejs}/bin/npx";
        "mcp.servers.my-mcp-server.args" = [ "@playwright/mcp@latest" ];
      };
    };
  };

  # Persistence: .vscode, .config/Code (declare in system-level persistence files)
}
