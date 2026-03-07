{ lib, ... }:
{
  programs.zsh.enable = lib.mkDefault true;
  programs.zsh.enableCompletion = lib.mkDefault true;
  programs.zsh.autosuggestion.enable = lib.mkDefault true;
  programs.zsh.syntaxHighlighting.enable = lib.mkDefault true;

  programs.zsh.history.size = 123456;

  # Force SSH_AUTH_SOCK to GPG agent (overrides COSMIC session environment)
  # This is needed because COSMIC starts gnome-keyring with --login which sets SSH_AUTH_SOCK
  # before Home Manager's sessionVariables are applied
  programs.zsh.initContent = ''
    # Use GPG agent for SSH authentication
    export SSH_AUTH_SOCK="''${XDG_RUNTIME_DIR:-/run/user/$UID}/gnupg/S.gpg-agent.ssh"
  '';
}
