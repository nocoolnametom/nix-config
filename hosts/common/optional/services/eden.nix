{ inputs, lib, ... }:
{
  imports = [ inputs.eden.nixosModules.default ];

  # Make sure to set this to _false_ for the machine in question on the first
  # time using this module to properly set up Cachix caching!
  programs.eden.enable = lib.mkDefault true;
  programs.eden.enableCache = lib.mkDefault true;
}
