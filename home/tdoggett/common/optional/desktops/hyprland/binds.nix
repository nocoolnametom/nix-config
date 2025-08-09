{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:

let
  usingSplit = config.wayland.windowManager.hyprland.settings.plugin.hyprsplit.enabled;
  usingHy3 = config.wayland.windowManager.hyprland.settings.plugin.hy3.enabled;
  menuCmd = "${pkgs.uwsm}/bin/uwsm app -- ${pkgs.wofi}/bin/wofi --show drun";
  termCmd = "${pkgs.uwsm}/bin/uwsm app -- ${pkgs.kitty}/bin/kitty";
  fileBrowseCmd = "${pkgs.uwsm}/bin/uwsm app -- ${pkgs.xfce.thunar}/bin/thunar";

  movePrefix = if usingHy3 then "hy3:" else "";
  moveFocus = "${movePrefix}movefocus";
  moveWindow = "${movePrefix}movewindow";
  splitChangeMonitorLeftCmd =
    if usingSplit then "split:swapactiveworkspaces, current -1" else "exec, :";
  splitChangeMonitorRightCmd =
    if usingSplit then "split:swapactiveworkspaces, current +1" else "exec, :";
  workspaceCmd = if usingSplit then "split:workspace" else "workspace";
  moveToWorkspaceCmdPrefix = if usingHy3 then "hy3:" else (if usingSplit then "split:" else "");
  moveToWorkspaceCmd = "${moveToWorkspaceCmdPrefix}movetoworkspace";
  moveToWorkspaceSilentCmd =
    if usingSplit then "split:movetoworkspacesilent" else "movetoworkspacesilent";
  spotlightApp = keypress: exec: ''
    bind = , ${keypress}, exec, ${pkgs.uwsm}/bin/uwsm app -- ${exec}
    bind = , ${keypress}, submap, reset
  '';
  submap = name: startBind: binds: ''
    bind = ${startBind}, submap, ${name}

    submap = ${name}
    ${binds}
    bind = , Escape, submap, reset
    bind = , Return, submap, reset
    submap = reset
  '';
in
{
  wayland.windowManager.hyprland.settings."$mainMod" = "SUPER";
  wayland.windowManager.hyprland.settings."$mehMod" = "ALT_SUPER_SHIFT";
  wayland.windowManager.hyprland.settings."$hyperMod" = "CONTROL_ALT_SUPER_SHIFT";
  wayland.windowManager.hyprland.settings.bind = [
    "$mainMod, Return, exec, ${termCmd}"
    "$mainMod SHIFT, Q, killactive,"
    "$mainMod SHIFT, E, exit,"
    "$mainMod SHIFT, space, togglefloating,"
    "$mainMod, D, exec, ${menuCmd}"
    "$mainMod, P, pseudo," # dwindle
    "$mainMod, A, fullscreen, 1" # fullscreen toggle (covers All of screen)

    # Cleanup orphaned windows on missing monitors if using hyprsplit
    "$mainMod, G, ${if usingSplit then "split:grabroguewindows" else "exec, :"}"

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

    # Switch workspaces with mainMod + [0-9]
    "$mainMod, 1, ${workspaceCmd}, 1"
    "$mainMod, 2, ${workspaceCmd}, 2"
    "$mainMod, 3, ${workspaceCmd}, 3"
    "$mainMod, 4, ${workspaceCmd}, 4"
    "$mainMod, 5, ${workspaceCmd}, 5"
    "$mainMod, 6, ${workspaceCmd}, 6"
    "$mainMod, 7, ${workspaceCmd}, 7"
    "$mainMod, 8, ${workspaceCmd}, 8"
    "$mainMod, 9, ${workspaceCmd}, 9"
    "$mainMod, 0, ${workspaceCmd}, 10"

    # Move active window to a workspace with mainMod + SHIFT + [0-9]
    "$mainMod SHIFT, 1, ${moveToWorkspaceCmd}, 1"
    "$mainMod SHIFT, 2, ${moveToWorkspaceCmd}, 2"
    "$mainMod SHIFT, 3, ${moveToWorkspaceCmd}, 3"
    "$mainMod SHIFT, 4, ${moveToWorkspaceCmd}, 4"
    "$mainMod SHIFT, 5, ${moveToWorkspaceCmd}, 5"
    "$mainMod SHIFT, 6, ${moveToWorkspaceCmd}, 6"
    "$mainMod SHIFT, 7, ${moveToWorkspaceCmd}, 7"
    "$mainMod SHIFT, 8, ${moveToWorkspaceCmd}, 8"
    "$mainMod SHIFT, 9, ${moveToWorkspaceCmd}, 9"
    "$mainMod SHIFT, 0, ${moveToWorkspaceCmd}, 10"

    # Floating Windows
    "$mainMod , F, togglefloating"
    # "$mainMod SHIFT, F, cyclenext, floating"

    # Example special workspace (scratchpad)
    "$mainMod, Minus, togglespecialworkspace, magic"
    "$mainMod SHIFT, minus, ${moveToWorkspaceCmd}, special:magic"

    # Move entire workspace to different monitor outputs
    "$hyperMod, L, ${splitChangeMonitorRightCmd}" # Move to monitor on right
    "$hyperMod, Right, ${splitChangeMonitorRightCmd}" # Move to monitor on right
    "$hyperMod, H, ${splitChangeMonitorLeftCmd}" # Move to monitor on left
    "$hyperMod, Left, ${splitChangeMonitorLeftCmd}" # Move to monitor on left
  ]
  ++ (lib.optionals (configVars.use-hy3) [

    # Hy3 Additional Bindings
    "$mainMod, B, hy3:makegroup, h"
    "$mainMod, V, hy3:makegroup, v"
    "$mainMod, S, hy3:changegroup, untab" # Stacked Layout
    "$mainMod, W, hy3:changegroup, tab" # Layout Tabbed
    "$mainMod, E, hy3:changegroup, opposite" # Toggle Split
  ]);

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
    # Window Resize Mode
    (submap "resize" "$mainMod, R" ''
      binde = , H, resizeactive, -10 0
      binde = , J, resizeactive, 0 10
      binde = , K, resizeactive, 0 -10
      binde = , L, resizeactive, 10 0
      binde = , Left, resizeactive, -10 0
      binde = , Down, resizeactive, 0 10
      binde = , Up, resizeactive, 0 -10
      binde = , Right, resizeactive, 10 0
    '')
    # Spotlight Mode for Fast App Launching
    + (submap "spotlighter" "$mainMod, O" ''
      ${spotlightApp "B" "brave"}
      ${spotlightApp "C" "code"}
      ${spotlightApp "C" "qtpass"}
      ${spotlightApp "E" "${fileBrowseCmd}"}
      ${spotlightApp "F" "firefox"}
      ${spotlightApp "G" "google-chrome-stable"}
      ${spotlightApp "M" "android-messages-desktop"}
      ${spotlightApp "P" "code"}
      ${spotlightApp "T" "thunderbird"}
      ${spotlightApp "Z" "${termCmd} -e ssh zg02911vmu"}
    '');
}
