{ pkgs, ... }:
{
  # User-level GUI packages to have installed
  home.packages = with pkgs; [ immersed-vr ];
}
