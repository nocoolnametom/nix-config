{
  pkgs,
  config,
  lib,
  ...
}:

{
  wayland.windowManager.hyprland.settings."$laptopScreen" = lib.mkDefault "eDP-1";
  wayland.windowManager.hyprland.settings."$bigExternalScreen" = lib.mkDefault "DP-1";
  wayland.windowManager.hyprland.settings.workspace = [ "" ];
}
