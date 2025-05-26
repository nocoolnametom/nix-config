{ pkgs, lib, ... }:
{
  services.waycorner.enable = lib.mkDefault true;
  services.waycorner.settings.main-monitor.enter_command = lib.mkDefault [
    "${pkgs.hyprland}/bin/hyprctl"
    "dispatch"
    "overview:toggle"
  ];
  # services.waycorner.settings.main-monitor.exit_command = lib.mkDefault [ "notify-send" "exit" ];
  services.waycorner.settings.main-monitor.locations = lib.mkDefault [
    "bottom_right"
    "bottom_left"
  ];
  services.waycorner.settings.main-monitor.size = lib.mkDefault 10;
  services.waycorner.settings.main-monitor.margin = lib.mkDefault 20;
  services.waycorner.settings.main-monitor.timeout_ms = lib.mkDefault 250;
  services.waycorner.settings.main-monitor.output.description = lib.mkDefault "";
  services.waycorner.settings.side-monitor.enter_command = lib.mkDefault [
    "${pkgs.hyprland}/bin/hyprctl"
    "dispatch"
    "overview:toggle"
  ];
  # services.waycorner.settings.side-monitor.exit_command = lib.mkDefault [ "notify-send" "exit" ];
  services.waycorner.settings.side-monitor.locations = lib.mkDefault [
    "bottom_right"
    "bottom_left"
  ];
  services.waycorner.settings.side-monitor.size = lib.mkDefault 10;
  services.waycorner.settings.side-monitor.margin = lib.mkDefault 20;
  services.waycorner.settings.side-monitor.timeout_ms = lib.mkDefault 250;
  services.waycorner.settings.side-monitor.output.description = lib.mkDefault "";
}
