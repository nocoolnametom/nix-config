{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.gpg-agent = {
    enable = true;
    enableSshSupport = lib.mkDefault true; # Use GPG agent for SSH authentication; set false on headless machines
    enableExtraSocket = true; # Needed for agent forwarding
    maxCacheTtl = 34560000; # ~400 days
    defaultCacheTtl = 34560000; # ~400 days
    defaultCacheTtlSsh = 34560000; # ~400 days for SSH keys
    maxCacheTtlSsh = 34560000; # ~400 days for SSH keys
    pinentry.package = lib.mkDefault pkgs.pinentry-gtk2; # Override to pinentry-tty on headless machines
  };

  # Disable GCR SSH agent socket (conflicts with gpg-agent)
  # This socket comes from gnome-keyring's gcr package and sets SSH_AUTH_SOCK
  systemd.user.sockets.gcr-ssh-agent = {
    Install.WantedBy = lib.mkForce [ ];
  };

  # Only point SSH_AUTH_SOCK at gpg-agent when it's actually handling SSH.
  # On headless machines (enableSshSupport = false), ssh-agent.nix sets its own socket.
  systemd.user.sessionVariables = lib.mkIf config.services.gpg-agent.enableSshSupport {
    SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/gnupg/S.gpg-agent.ssh";
  };
  home.sessionVariables = lib.mkIf config.services.gpg-agent.enableSshSupport {
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/gnupg/S.gpg-agent.ssh";
  };
}
