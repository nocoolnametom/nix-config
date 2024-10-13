# Add your reusable NixOS modules to this directory, on their own file (https://wiki.nixos.org/wiki/NixOS_modules).
# These should be stuff you would like to share with others, not your personal configurations.
{
  # List your module files here
  # my-module = import ./my-module.nix;
  flood = import ./flood.nix; # Floos has been added to 24.11+/unstable!
  maestral = import ./maestral.nix;
  per-user-vpn = import ./per-user-vpn.nix;
  stashapp = import ./stashapp.nix;
  sauronsync = import ./sauronsync.nix;
  yubikey = import ./yubikey.nix;
  zsa-udev-rules = import ./zsa-udev-rules.nix;
}
