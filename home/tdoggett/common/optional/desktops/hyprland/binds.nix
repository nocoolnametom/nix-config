{ pkgs, config, ... }:

let
  menuCmd = "${pkgs.wofi}/bin/wofi --show drun";
  termCmd = "${pkgs.kitty}/bin/kitty";
  fileBrowseCmd = "${pkgs.xfce.thunar}/bin/thunar";
  moveFocus =
    if (config.wayland.windowManager.hyprland.settings.general.layout == "hy3") then
      "hy3:movefocus"
    else
      "movefocus";
  moveWindow =
    if (config.wayland.windowManager.hyprland.settings.general.layout == "hy3") then
      "hy3:movewindow"
    else
      "movewindow";
in
{
  wayland.windowManager.hyprland.settings."$mainMod" = "SUPER";
  wayland.windowManager.hyprland.settings.bind = [
    "$mainMod, Q, exec, ${termCmd}"
    "$mainMod, C, killactive,"
    "$mainMod, M, exit,"
    "$mainMod, E, exec, ${fileBrowseCmd}"
    "$mainMod, V, togglefloating,"
    "$mainMod, R, exec, ${menuCmd}"
    "$mainMod, P, pseudo," # dwindle
    "$mainMod, J, togglesplit," # dwindle

    # Move focus with mainMod + arrow keys
    "$mainMod, left, ${moveFocus}, l"
    "$mainMod, right, ${moveFocus}, r"
    "$mainMod, up, ${moveFocus}, u"
    "$mainMod, down, ${moveFocus}, d"

    # Switch workspaces with mainMod + [0-9]
    "$mainMod, 1, workspace, 1"
    "$mainMod, 2, workspace, 2"
    "$mainMod, 3, workspace, 3"
    "$mainMod, 4, workspace, 4"
    "$mainMod, 5, workspace, 5"
    "$mainMod, 6, workspace, 6"
    "$mainMod, 7, workspace, 7"
    "$mainMod, 8, workspace, 8"
    "$mainMod, 9, workspace, 9"
    "$mainMod, 0, workspace, 10"

    # Move active window to a workspace with mainMod + SHIFT + [0-9]
    "$mainMod SHIFT, 1, movetoworkspace, 1"
    "$mainMod SHIFT, 2, movetoworkspace, 2"
    "$mainMod SHIFT, 3, movetoworkspace, 3"
    "$mainMod SHIFT, 4, movetoworkspace, 4"
    "$mainMod SHIFT, 5, movetoworkspace, 5"
    "$mainMod SHIFT, 6, movetoworkspace, 6"
    "$mainMod SHIFT, 7, movetoworkspace, 7"
    "$mainMod SHIFT, 8, movetoworkspace, 8"
    "$mainMod SHIFT, 9, movetoworkspace, 9"
    "$mainMod SHIFT, 0, movetoworkspace, 10"

    # Example special workspace (scratchpad)
    "$mainMod, S, togglespecialworkspace, magic"
    "$mainMod SHIFT, S, movetoworkspace, special:magic"

    # Scroll through existing workspaces with mainMod + scroll
    "$mainMod, mouse_down, workspace, e+1"
    "$mainMod, mouse_up, workspace, e-1"

    # Special key handling
    # ", XF86MonBrightnessDown, exec, ${pkgs.light}/bin/light -U 10"
    # ", XF86MonBrightnessUp,   exec, ${pkgs.light}/bin/light -A 10"
    ", XF86AudioRaiseVolume,  exec, ${pkgs.pamixer}/bin/pamixer -i 5"
    ", XF86AudioLowerVolume,  exec, ${pkgs.pamixer}/bin/pamixer -d 5"
    ", XF86AudioMute,         exec, ${pkgs.pamixer}/bin/pamixer -t"
  ];

  # Move/resize windows with mainMod + LMB/RMB and dragging
  wayland.windowManager.hyprland.settings.bindm = [
    "$mainMod, mouse:272, ${moveWindow}"
    "$mainMod, mouse:273, resizewindow"
  ];
}
