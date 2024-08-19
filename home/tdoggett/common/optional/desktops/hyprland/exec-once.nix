{ pkgs, ... }:

let
  networkmanagerapplet = "${pkgs.networkmanagerapplet}/bin/nm-applet";
  policykitAgentCmd = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
in
{
  wayland.windowManager.hyprland.settings.exec-once = [
    # "${networkmanagerapplet} &"
    "${policykitAgentCmd} &"
  ];
}
