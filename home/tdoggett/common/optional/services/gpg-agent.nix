{ pkgs, lib, ... }:
{
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;  # Use GPG agent for SSH authentication
    enableExtraSocket = true;  # Needed for agent forwarding
    maxCacheTtl = 34560000;    # ~400 days
    defaultCacheTtl = 34560000; # ~400 days
    defaultCacheTtlSsh = 34560000; # ~400 days for SSH keys
    maxCacheTtlSsh = 34560000;     # ~400 days for SSH keys
    pinentry.package = lib.mkForce pkgs.pinentry-gtk2;
  };

  # Disable GCR SSH agent socket (conflicts with gpg-agent)
  # This socket comes from gnome-keyring's gcr package and sets SSH_AUTH_SOCK
  systemd.user.sockets.gcr-ssh-agent = {
    Install.WantedBy = lib.mkForce [];
  };

  # Ensure SSH uses GPG agent by setting it in systemd user environment
  # Using systemd.user.sessionVariables ensures it's set before any services start
  systemd.user.sessionVariables = {
    SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh";
  };

  # Also set in shell for good measure
  home.sessionVariables = {
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/gnupg/S.gpg-agent.ssh";
  };
}
