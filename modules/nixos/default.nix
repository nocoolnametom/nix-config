# Add your reusable NixOS modules to this directory, on their own file (https://wiki.nixos.org/wiki/NixOS_modules).
# These should be stuff you would like to share with others, not your personal configurations.
{
  # List your module files here
  # my-module = import ./my-module.nix;
  failover-redirects = import ./failover-redirects.nix;
  maestral = import ./maestral.nix;
  nzbget-to-management = import ./nzbget-to-management.nix;
  per-user-vpn = import ./per-user-vpn.nix;
  rsync-cert-sync = import ./rsync-cert-sync.nix;
  sauronsync = import ./sauronsync.nix;
  systemd-failure-alert = import ./systemd-failure-alert.nix;
  stashapp = import ./stashapp.nix;
  yubikey = import ./yubikey.nix;
  zsa-udev-rules = import ./zsa-udev-rules.nix;
}
