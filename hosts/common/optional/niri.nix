{ pkgs, lib, ... }:
{
  programs.niri.enable = lib.mkDefault true;
}
