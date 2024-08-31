# Add your reusable Home Manager modules to this directory, on their own files.
# These should be stuff you would like to share with others, not your personal configurations.
{
  # List your module files here
  davmail-config = import ./davmail-config.nix;
  waynergy = import ./waynergy.nix;
}
