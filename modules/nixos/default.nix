# Add your reusable NixOS modules to this directory, on their own file (https://wiki.nixos.org/wiki/NixOS_modules).
# These should be stuff you would like to share with others, not your personal configurations.
{
  # List your module files here
  # my-module = import ./my-module.nix;
  deprecation = import ./deprecation.nix;
  dns-failover = import ./dns-failover.nix;
  failover-redirects = import ./failover-redirects.nix;
  kavitan = import ./kavitan.nix;
  maestral = import ./maestral.nix;
  nzbget-to-management = import ./nzbget-to-management.nix;
  per-user-vpn = import ./per-user-vpn.nix;
  rsync-cert-sync = import ./rsync-cert-sync.nix;
  sauronsync = import ./sauronsync.nix;
  stash-video-conversion = import ./stash-video-conversion.nix;
  stash-vr-helper = import ./stash-vr-helper.nix;
  mormonsites = import ./mormonsites.nix;
  systemd-failure-alert = import ./systemd-failure-alert.nix;
  work-block = import ./work-block.nix;
  yubikey = import ./yubikey.nix;
  zsa-udev-rules = import ./zsa-udev-rules.nix;
}
