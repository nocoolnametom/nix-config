{ lib, pkgs, ... }:
{
  programs.zsh = lib.mkMerge [
    {
      enable = true;
      enableCompletion = true;
    }
    (lib.optionalAttrs (pkgs.stdenv.isDarwin) {
      enableSyntaxHighlighting = true;
    })
  ];
}
