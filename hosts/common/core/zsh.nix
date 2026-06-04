{ lib, pkgs, ... }:
{
  programs.zsh = lib.mkMerge [
    {
      enable = true;
      enableCompletion = true;
    }
    (lib.optionalAttrs (pkgs.stdenv.isDarwin) {
      enableSyntaxHighlighting = true;
      # Skip /etc/zshrc's `compinit` (no -C). The user-level zshrc uses `compinit -C`
      # and a launchd agent regenerates ~/.zcompdump daily and at login.
      # Saves ~2.6s per interactive shell startup on darwin.
      enableGlobalCompInit = false;
    })
  ];
}
