{ pkgs, ... }:
{
  programs.vscode = {
    enableUpdateCheck = false;
    mutableExtensionsDir = true;
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
      "update.mode" = "none";
      "telemetry.telemetryLevel" = "error";
      "redhat.telemetry.enabled" = false;
    };
  };
}
