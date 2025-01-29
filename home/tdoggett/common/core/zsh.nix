{ lib, ... }:
{
  programs.zsh.enable = lib.mkDefault true;
  programs.zsh.enableCompletion = lib.mkDefault true;
  programs.zsh.autosuggestion.enable = lib.mkDefault true;
  programs.zsh.syntaxHighlighting.enable = lib.mkDefault true;

  programs.zsh.history.size = 123456;
}
