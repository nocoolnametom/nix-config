{ lib, pkgs, ... }:
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
  programs.bash = {
    enable = lib.mkDefault true;
    enableCompletion = lib.mkDefault true;

    # Override SSH_AUTH_SOCK for local sessions only.
    # Skipped when SSH agent forwarding is active so the forwarded agent is used instead.
    initExtra = ''
      if [[ -z "$SSH_CLIENT" && -z "$SSH_CONNECTION" ]]; then
        ${sshAuthSockLine}
      fi
    '';
  };
}
