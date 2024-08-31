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
      "redhat.telemetry.enabled" = false;
      "telemetry.telemetryLevel" = "error";
      "update.mode" = "none";
      "workbench.editor.pinnedTabsOnSeparateRow" = true;
      "workbench.editor.wrapTabs" = true;
    };
  };
}
