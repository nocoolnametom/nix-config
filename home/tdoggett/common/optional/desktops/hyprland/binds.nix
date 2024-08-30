{
  pkgs,
  lib,
  config,
  ...
}:

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
  hy3mod =
    if (config.wayland.windowManager.hyprland.settings.general.layout == "hy3") then
      "$mainMod"
    else
      "$mainMod F35";
in
{
  wayland.windowManager.hyprland.settings."$mainMod" = "SUPER";
  wayland.windowManager.hyprland.settings."$mehMod" = "ALT SUPER SHIFT";
  wayland.windowManager.hyprland.settings."$hyperMod" = "CRLT ALT SUPER SHIFT";
  wayland.windowManager.hyprland.settings.bind = [
    "$mainMod, Return, exec, ${termCmd}"
    "$mainMod SHIFT, Q, killactive,"
    "$mainMod SHIFT, E, exit,"
    "$mainMod SHIFT, space, togglefloating,"
    "$mainMod, D, exec, ${menuCmd}"
    "$mainMod, P, pseudo," # dwindle
    "$mainMod, F, fullscreen, 1" # fullscreen toggle

    # Move focus with mainMod + hjkl and arrow keys
    "$mainMod, H, ${moveFocus}, l"
    "$mainMod, J, ${moveFocus}, d"
    "$mainMod, K, ${moveFocus}, u"
    "$mainMod, L, ${moveFocus}, r"
    "$mainMod, Left, ${moveFocus}, l"
    "$mainMod, Down, ${moveFocus}, d"
    "$mainMod, Up, ${moveFocus}, u"
    "$mainMod, Right, ${moveFocus}, r"

    # Move windows with mainMod + shift + hjkl and arrow keys
    "$mainMod SHIFT, H, ${moveWindow}, l"
    "$mainMod SHIFT, J, ${moveWindow}, d"
    "$mainMod SHIFT, K, ${moveWindow}, u"
    "$mainMod SHIFT, L, ${moveWindow}, r"
    "$mainMod SHIFT, Left, ${moveWindow}, l"
    "$mainMod SHIFT, Down, ${moveWindow}, d"
    "$mainMod SHIFT, Up, ${moveWindow}, u"
    "$mainMod SHIFT, Right, ${moveWindow}, r"

    # Move entire workspace to different monitor outputs
    "$hyperMod, L, movecurrentworkspacetomonitor, r" # Move to monitor on right
    "$hyperMod, H, movecurrentworkspacetomonitor, l" # Move to monitor on left

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

    # Floating Windows
    "$mainMod , F, togglefloating"
    # "$mainMod SHIFT, F, cyclenext, floating"

    # Example special workspace (scratchpad)
    "$mainMod, Minus, togglespecialworkspace, magic"
    "$mainMod SHIFT, minus, movetoworkspace, special:magic"

    # Hy3 Additional Bindings (when hy3 is not active will bind to F35 key)
    "${hy3mod}, B, hy3:makegroup, h"
    "${hy3mod}, V, hy3:makegroup, v"
    "${hy3mod}, S, hy3:changegroup, untab" # Stacked Layout
    "${hy3mod}, W, hy3:changegroup, tab" # Layout Tabbed
    "${hy3mod}, E, hy3:changegroup, opposite" # Toggle Split
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

  wayland.windowManager.hyprland.extraConfig =
    let
      spotlightApp = keypress: exec: ''
        bind = , ${keypress}, exec, ${exec}
        bind = , ${keypress}, submap, reset
      '';
    in
    ''
      # Window Resize Mode
      bind = $mainMod, R, submap, resize

      submap = resize
      binde = , H, resizeactive, -10 0
      binde = , J, resizeactive, 0 10
      binde = , K, resizeactive, 0 -10
      binde = , L, resizeactive, 10 0
      binde = , Left, resizeactive, -10 0
      binde = , Down, resizeactive, 0 10
      binde = , Up, resizeactive, 0 -10
      binde = , Right, resizeactive, 10 0
      bind = , Escape, submap, reset
      bind = , Return, submap, reset
      submap = reset

      # Spotlight Mode for Fast App Launching
      bind = $mainMod, O, submap, spotlighter

      submap = spotlighter
      ${spotlightApp "E" "brave"}
      ${spotlightApp "C" "code"}
      ${spotlightApp "F" "firefox"}
      ${spotlightApp "G" "google-chrome-stable"}
      ${spotlightApp "M" "android-messages-desktop"}
      ${spotlightApp "C" "qtpass"}
      ${spotlightApp "P" "code"}
      ${spotlightApp "T" "thunderbird"}
      ${spotlightApp "Z" "${termCmd} -e ssh zg02911vmu"}
      ${spotlightApp "E" "${fileBrowseCmd}"}
      bind = , Escape, submap, reset
      bind = , Return, submap, reset
      submap = reset
    '';
}
