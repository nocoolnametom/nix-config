{ ... }:
{
  # Don't use this WITH Lanzaboote!
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
