# Add your reusable Home Manager modules to this directory, on their own files.
# These should be stuff you would like to share with others, not your personal configurations.
{
  # List your module files here
  # TODO: Remove once home-manager release-26.05 is adopted — module is upstream in master.
  colima = import ./colima.nix;
  davmail-config = import ./davmail-config.nix;
  waycorner = import ./waycorner.nix;
  waynergy = import ./waynergy.nix;
  yubikey-touch-detector = import ./yubikey-touch-detector.nix;
}
