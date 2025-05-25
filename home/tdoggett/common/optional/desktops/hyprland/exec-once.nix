{ pkgs, ... }:

let
  networkmanagerapplet = "${pkgs.networkmanagerapplet}/bin/nm-applet";
  policykitAgentCmd = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
in
{
  wayland.windowManager.hyprland.settings.exec-once = [
    "${pkgs.uwsm}/bin/uwsm app -- ${networkmanagerapplet}"
    "${pkgs.uwsm}/bin/uwsm app -- ${policykitAgentCmd}"
  ];
}
