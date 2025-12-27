{ lib, ... }:
{
  programs.firefox.enable = lib.mkDefault true;
}
