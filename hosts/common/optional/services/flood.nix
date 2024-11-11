{ lib, ... }:
{
  # Flood UI
  services.flood.enable = lib.mkDefault true;
}
