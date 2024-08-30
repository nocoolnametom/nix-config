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
    "$mainMod, enter, exec, ${termCmd}"
    "$mainMod SHIFT, Q, killactive,"
    "$mainMod SHIFT, E, exit,"
    "$mainMod, E, exec, ${fileBrowseCmd}"
    "$mainMod SHIFT, space, togglefloating,"
    "$mainMod, D, exec, ${menuCmd}"
    "$mainMod, P, pseudo," # dwindle
    #"$mainMod, J, togglesplit," # dwindle

    # Move focus with mainMod + hjkl and arrow keys
    "$mainMod, H, ${moveFocus}, l"
    "$mainMod, J, ${moveFocus}, d"
    "$mainMod, K, ${moveFocus}, u"
    "$mainMod, L, ${moveFocus}, r"
    "$mainMod, left, ${moveFocus}, l"
    "$mainMod, down, ${moveFocus}, d"
    "$mainMod, up, ${moveFocus}, u"
    "$mainMod, right, ${moveFocus}, r"

    # Move windows with mainMod + shift + hjkl and arrow keys
    "$mainMod SHIFT, H, ${moveWindow}, l"
    "$mainMod SHIFT, J, ${moveWindow}, d"
    "$mainMod SHIFT, K, ${moveWindow}, u"
    "$mainMod SHIFT, L, ${moveWindow}, r"
    "$mainMod SHIFT, left, ${moveWindow}, l"
    "$mainMod SHIFT, down, ${moveWindow}, d"
    "$mainMod SHIFT, up, ${moveWindow}, u"
    "$mainMod SHIFT, right, ${moveWindow}, r"

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
    "$mainMod, minus, togglespecialworkspace, magic"
    "$mainMod SHIFT, minus, movetoworkspace, special:magic"
  ];

  # Always active keys, no matter what
  wayland.windowManager.hyprland.settings.bindl = [
    # Special key handling, brightness is best handled by system-wide light service
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

  wayland.windowManager.hyprland.extraConfig = let
    spotlightApp = keypress: exec: ''
      bind = , ${keypress}, exec, ${exec}
      bind = , ${keypress}, submap, reset
    '';
  in ''
    # Window Resize Mode
    bind = $mainMod, R, submap, resize

    submap = resize
    bind = , escape, submap, reset
    binde = , H, resizeactive, -10 0
    binde = , J, resizeactive, 0 10
    binde = , K, resizeactive, 0 -10
    binde = , L, resizeactive, 10 0
    binde = , left, resizeactive, -10 0
    binde = , down, resizeactive, 0 10
    binde = , up, resizeactive, 0 -10
    binde = , right, resizeactive, 10 0
    submap = reset

    # Spotlight Mode for Fast App Launching
    bind = $mainMod, O, submap, spotlight
    submap = spotlight
    bind = , escape, submap, reset
    ${spotlightApp "E" "brave"}
    ${spotlightApp "C" "code"}
    ${spotlightApp "F" "firefox"}
    ${spotlightApp "G" "google-chrome-stable"}
    ${spotlightApp "M" "android-messages-desktop"}
    ${spotlightApp "C" "qtpass"}
    ${spotlightApp "P" "code"}
    ${spotlightApp "T" "thunderbird"}
    ${spotlightApp "Z" "${termCmd} -e ssh zg02911vmu"}
    submap = reset
  '';
}
