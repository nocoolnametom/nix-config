{ pkgs, lib, ... }: {
  programs.thunar.enable = lib.mkDefault true;
  programs.thunar.plugins = [
    pkgs.xfce.thunar-archive-plugin
    pkgs.xfce.thunar-volman
  ];
  services.gvfs.enable = lib.mkDefault true; # Mount, trash, and other functionalities
  services.tumbler.enable = lib.mkDefault true; # Thumbnail support for images
}
