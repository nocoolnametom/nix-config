{ lib, ... }:
{
  programs.git.enable = lib.mkDefault true;
  # More detailed git setup is through home-manager
}
