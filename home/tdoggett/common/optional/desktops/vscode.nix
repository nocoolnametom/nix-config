{ pkgs, lib, ... }:
{
  programs.vscode = {
    enableUpdateCheck = lib.mkDefault false;
    mutableExtensionsDir = lib.mkDefault true;
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
      "editor.minimap.autohide" = true;
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
    };
  };
}
