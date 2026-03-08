{ lib, ... }:
{
  programs.bash = {
    enable = lib.mkDefault true;
    enableCompletion = lib.mkDefault true;

    # Force SSH_AUTH_SOCK to GPG agent (overrides COSMIC session environment)
    # This is needed because COSMIC starts gnome-keyring with --login which sets SSH_AUTH_SOCK
    # before Home Manager's sessionVariables are applied.
    # Skip this override when SSH agent forwarding is active (i.e. when SSH'd in from another machine)
    # so that the forwarded agent (e.g. Yubikey on the connecting host) is used instead.
    initExtra = ''
      # Use GPG agent for SSH authentication (local sessions only)
      if [[ -z "$SSH_CLIENT" && -z "$SSH_CONNECTION" ]]; then
        export SSH_AUTH_SOCK="''${XDG_RUNTIME_DIR:-/run/user/$UID}/gnupg/S.gpg-agent.ssh"
      fi
    '';
  };
}
