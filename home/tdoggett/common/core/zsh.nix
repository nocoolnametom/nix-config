{
  lib,
  pkgs,
  config,
  ...
}:
let
  # Platform-specific SSH_AUTH_SOCK:
  #   Darwin: brew ssh-agent at a stable known path (see modules/darwin/yubikey.nix)
  #   Linux:  gpg-agent SSH socket (needed to override gnome-keyring on COSMIC)
  sshAuthSockLine =
    if pkgs.stdenv.isDarwin then
      "export SSH_AUTH_SOCK=\"$HOME/.ssh/sockets/ssh-agent.sock\""
    else
      "export SSH_AUTH_SOCK=\"\${XDG_RUNTIME_DIR:-/run/user/$UID}/gnupg/S.gpg-agent.ssh\"";
in
{
  programs.zsh.enable = lib.mkDefault true;
  # LEGACY BEHAVIOR (26.05): New default will move zsh dotfiles to $XDG_CONFIG_HOME/zsh.
  # Keeping home dir for now to avoid needing to migrate .zshrc, .zshenv, etc.
  # To adopt new behavior: set to "${config.xdg.configHome}/zsh" and move existing dotfiles.
  programs.zsh.dotDir = config.home.homeDirectory;
  programs.zsh.enableCompletion = lib.mkDefault true;
  programs.zsh.autosuggestion.enable = lib.mkDefault true;
  programs.zsh.syntaxHighlighting.enable = lib.mkDefault true;

  programs.zsh.history.size = 123456;

  # Override SSH_AUTH_SOCK for local sessions only.
  # Skipped when SSH agent forwarding is active so the forwarded agent is used instead.
  programs.zsh.initContent = ''
    if [[ -z "$SSH_CLIENT" && -z "$SSH_CONNECTION" ]]; then
      ${sshAuthSockLine}
    fi
  '';
}
