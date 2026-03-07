{ pkgs, lib, ... }:
{
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = lib.mkForce pkgs.pinentry-gtk2;
  };

  # Set GPG_TTY for proper terminal interaction
  # Note: SSH_AUTH_SOCK is set in home-manager config to avoid shell expansion issues
  environment.extraInit = ''
    export GPG_TTY=$(tty)
  '';
}
