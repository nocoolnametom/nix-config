{ lib, ... }:
{
  programs.bash = {
    enable = lib.mkDefault true;
    enableCompletion = lib.mkDefault true;

    # Force SSH_AUTH_SOCK to GPG agent (overrides COSMIC session environment)
    # This is needed because COSMIC starts gnome-keyring with --login which sets SSH_AUTH_SOCK
    # before Home Manager's sessionVariables are applied
    initExtra = ''
      # Use GPG agent for SSH authentication
      export SSH_AUTH_SOCK="''${XDG_RUNTIME_DIR:-/run/user/$UID}/gnupg/S.gpg-agent.ssh"
    '';
  };
}
