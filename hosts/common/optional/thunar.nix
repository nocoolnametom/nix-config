{ pkgs, lib, ... }:
{
  programs.thunar.enable = lib.mkDefault true;
  programs.thunar.plugins = [
    pkgs.thunar-archive-plugin
    pkgs.thunar-volman
  ];
  services.gvfs.enable = lib.mkDefault true; # Mount, trash, and other functionalities
  services.tumbler.enable = lib.mkDefault true; # Thumbnail support for images
}
