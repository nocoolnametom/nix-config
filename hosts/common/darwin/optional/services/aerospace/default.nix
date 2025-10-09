{ lib, config, ... }:
let
  sketchybarCfg = config.services.sketchybar;
  sketchybar =
    if sketchybarCfg.enable then "${sketchybarCfg.package}/bin/sketchybar" else "sketchybar";
  hyper = "alt-ctrl-shift-cmd";
  meh = "alt-ctrl-shift";
in
{
  services.aerospace.enable = lib.mkDefault true;

  # You can use it to add commands that run after AeroSpace startup.
  # Available commands : https://nikitabobko.github.io/AeroSpace/commands
  services.aerospace.settings.after-startup-command = lib.mkDefault [ ];

  services.aerospace.settings.exec-on-workspace-change = lib.mkDefault [
    "/bin/bash"
    "-c"
    "${sketchybar} --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
  ];

  # Normalizations. See: https://nikitabobko.github.io/AeroSpace/guide#normalization
  services.aerospace.settings.enable-normalization-flatten-containers = lib.mkDefault true;
  services.aerospace.settings.enable-normalization-opposite-orientation-for-nested-containers = lib.mkDefault true;

  # See: https://nikitabobko.github.io/AeroSpace/guide#layouts
  # The "accordion-padding" specifies the size of accordion padding
  # You can set 0 to disable the padding feature
  services.aerospace.settings.accordion-padding = lib.mkDefault 300;

  # Possible values: tiles|accordion
  services.aerospace.settings.default-root-container-layout = lib.mkDefault "tiles";

  # Possible values: horizontal|vertical|auto
  # "auto" means: wide monitor (anything wider than high) gets horizontal orientation,
  #               tall monitor (anything higher than wide) gets vertical orientation
  services.aerospace.settings.default-root-container-orientation = lib.mkDefault "auto";

  # Mouse follows focus when focused monitor changes
  # Drop it from your config, if you don't like this behavior
  # See https://nikitabobko.github.io/AeroSpace/guide#on-focus-changed-callbacks
  # See https://nikitabobko.github.io/AeroSpace/commands#move-mouse
  # Fallback value (if you omit the key): on-focused-monitor-changed = []
  services.aerospace.settings.on-focused-monitor-changed = lib.mkDefault [
    "move-mouse monitor-lazy-center"
  ];

  # You can effectively turn off macOS "Hide application" (cmd-h) feature by toggling this flag
  # Useful if you don't use this macOS feature, but accidentally hit cmd-h or cmd-alt-h key
  # Also see: https://nikitabobko.github.io/AeroSpace/goodies#disable-hide-app
  services.aerospace.settings.automatically-unhide-macos-hidden-apps = lib.mkDefault false;

  services.aerospace.settings.on-window-detected = lib.mkDefault (
    [
      {
        "if".app-name-regex-substring = "Finder";
        run = "layout floating";
      }
      {
        "if".window-title-regex-substring = "Updating iTerm";
        run = "layout floating";
      }
      {
        # Float the MAIN Apple Music window, but NOT the miniplayer!
        "if".app-id = "com.apple.Music";
        "if".window-title-regex-substring = "(Music|Activity|Equalizer)";
        run = "layout floating";
      }
    ]
    # Float these apps by default
    ++ (builtins.map
      (app_id: {
        "if".app-id = app_id;
        run = "layout floating";
      })
      [
        # Finder
        "com.apple.finder"
        # Activity Monitor
        "com.apple.ActivityMonitor"
        # Zoom.us
        "us.zoom.xos"
        # Proton Mail Bridge
        "com.protonmail.bridge"
        # Cisco Secure Client
        "com.cisco.secureclient.gui"
        # Cisco Secure Client - Socket Filter
        "com.cisco.anyconnect.macos.acsock"
        # Cisco Secure Client - DART
        "com.cisco.secureclient.dart"
        # Okta Verify
        "com.okta.mobile"
        # Logitech G HUB
        "com.logi.ghub"
      ]
    )
  );

  # Possible values: (qwerty|dvorak|colemak)
  # See https://nikitabobko.github.io/AeroSpace/guide#key-mapping
  services.aerospace.settings.key-mapping.preset = lib.mkDefault "qwerty";

  # Gaps between windows (inner-*) and between monitor edges (outer-*).
  # Possible values:
  # - Constant:     gaps.outer.top = 8
  # - Per monitor:  gaps.outer.top = [{ monitor.main = 16 }, { monitor."some-pattern" = 32 }, 24]
  #                 In this example, 24 is a default value when there is no match.
  #                 Monitor pattern is the same as for "workspace-to-monitor-force-assignment".
  #                 See:
  #                 https://nikitabobko.github.io/AeroSpace/guide#assign-workspaces-to-monitors
  services.aerospace.settings.gaps.inner.horizontal = lib.mkDefault 4;
  services.aerospace.settings.gaps.inner.vertical = lib.mkDefault 4;
  services.aerospace.settings.gaps.outer.left = lib.mkDefault 4;
  services.aerospace.settings.gaps.outer.bottom = lib.mkDefault 4;
  services.aerospace.settings.gaps.outer.top = lib.mkDefault 40;
  services.aerospace.settings.gaps.outer.right = lib.mkDefault 4;

  services.aerospace.settings.workspace-to-monitor-force-assignment."1" = lib.mkDefault [
    "built-in"
    "secondary"
  ];
  services.aerospace.settings.workspace-to-monitor-force-assignment."2" = lib.mkDefault [
    "built-in"
    "secondary"
  ];
  services.aerospace.settings.workspace-to-monitor-force-assignment."3" = lib.mkDefault [
    "built-in"
    "secondary"
  ];
  services.aerospace.settings.workspace-to-monitor-force-assignment."4" = lib.mkDefault [
    "built-in"
    "secondary"
  ];
  services.aerospace.settings.workspace-to-monitor-force-assignment."5" = lib.mkDefault [
    "built-in"
    "secondary"
  ];
  services.aerospace.settings.workspace-to-monitor-force-assignment."6" = lib.mkDefault [
    "built-in"
    "main"
  ];
  services.aerospace.settings.workspace-to-monitor-force-assignment."7" = lib.mkDefault [
    "built-in"
    "main"
  ];
  services.aerospace.settings.workspace-to-monitor-force-assignment."8" = lib.mkDefault [
    "built-in"
    "main"
  ];
  services.aerospace.settings.workspace-to-monitor-force-assignment."9" = lib.mkDefault [
    "built-in"
    "main"
  ];
  services.aerospace.settings.workspace-to-monitor-force-assignment."A" = lib.mkDefault [
    "built-in"
    "main"
  ];

  # "main" binding mode declaration
  # See: https://nikitabobko.github.io/AeroSpace/guide#binding-modes
  # "main" binding mode must be always presented
  # Fallback value (if you omit the key): mode.main.binding = {}
  # All possible keys:
  # - Letters.        a, b, c, ..., z
  # - Numbers.        0, 1, 2, ..., 9
  # - Keypad numbers. keypad0, keypad1, keypad2, ..., keypad9
  # - F-keys.         f1, f2, ..., f20
  # - Special keys.   minus, equal, period, comma, slash, backslash, quote, semicolon,
  #                   backtick, leftSquareBracket, rightSquareBracket, space, enter, esc,
  #                   backspace, tab, pageUp, pageDown, home, end, forwardDelete,
  #                   sectionSign (ISO keyboards only, european keyboards only)
  # - Keypad special. keypadClear, keypadDecimalMark, keypadDivide, keypadEnter, keypadEqual,
  #                   keypadMinus, keypadMultiply, keypadPlus
  # - Arrows.         left, down, up, right

  # All possible modifiers: cmd, alt, ctrl, shift

  # All possible commands: https://nikitabobko.github.io/AeroSpace/commands

  # See: https://nikitabobko.github.io/AeroSpace/commands#exec-and-forget
  # You can uncomment the following lines to open up terminal with alt + enter shortcut
  # (like in i3)
  # alt-enter = ''"exec-and-forget osascript -e "
  # tell application "Terminal"
  #     do script
  #     activate
  # end tell'
  # '''

  # See: https://nikitabobko.github.io/AeroSpace/commands#layout
  services.aerospace.settings.mode.main.binding.alt-slash =
    lib.mkDefault "layout tiles horizontal vertical";
  services.aerospace.settings.mode.main.binding.alt-comma =
    lib.mkDefault "layout accordion horizontal vertical";

  # See: https://nikitabobko.github.io/AeroSpace/commands#focus
  services.aerospace.settings.mode.main.binding."${hyper}-h" = lib.mkDefault "focus left";
  services.aerospace.settings.mode.main.binding."${hyper}-j" = lib.mkDefault "focus down";
  services.aerospace.settings.mode.main.binding."${hyper}-k" = lib.mkDefault "focus up";
  services.aerospace.settings.mode.main.binding."${hyper}-l" = lib.mkDefault "focus right";

  # See: https://nikitabobko.github.io/AeroSpace/commands#move
  services.aerospace.settings.mode.main.binding."${meh}-h" = lib.mkDefault "move left";
  services.aerospace.settings.mode.main.binding."${meh}-j" = lib.mkDefault "move down";
  services.aerospace.settings.mode.main.binding."${meh}-k" = lib.mkDefault "move up";
  services.aerospace.settings.mode.main.binding."${meh}-l" = lib.mkDefault "move right";

  # See: https://nikitabobko.github.io/AeroSpace/commands#resize
  services.aerospace.settings.mode.main.binding."${meh}-minus" = lib.mkDefault "resize smart -50";
  services.aerospace.settings.mode.main.binding."${meh}-equal" = lib.mkDefault "resize smart +50";
  services.aerospace.settings.mode.main.binding."${meh}-f" = lib.mkDefault "fullscreen";

  # See: https://nikitabobko.github.io/AeroSpace/commands#workspace
  services.aerospace.settings.mode.main.binding."${hyper}-left" = lib.mkDefault "workspace prev";
  services.aerospace.settings.mode.main.binding."${hyper}-right" = lib.mkDefault "workspace next";
  services.aerospace.settings.mode.main.binding."${hyper}-up" = lib.mkDefault "focus-monitor prev";
  services.aerospace.settings.mode.main.binding."${hyper}-down" = lib.mkDefault "focus-monitor next";
  services.aerospace.settings.mode.main.binding."${meh}-1" = lib.mkDefault "workspace 1";
  services.aerospace.settings.mode.main.binding."${meh}-2" = lib.mkDefault "workspace 2";
  services.aerospace.settings.mode.main.binding."${meh}-3" = lib.mkDefault "workspace 3";
  services.aerospace.settings.mode.main.binding."${meh}-4" = lib.mkDefault "workspace 4";
  services.aerospace.settings.mode.main.binding."${meh}-5" = lib.mkDefault "workspace 5";
  services.aerospace.settings.mode.main.binding."${meh}-6" = lib.mkDefault "workspace 6";
  services.aerospace.settings.mode.main.binding."${meh}-7" = lib.mkDefault "workspace 7";
  services.aerospace.settings.mode.main.binding."${meh}-8" = lib.mkDefault "workspace 8";
  services.aerospace.settings.mode.main.binding."${meh}-9" = lib.mkDefault "workspace 9";
  services.aerospace.settings.mode.main.binding."${meh}-0" = lib.mkDefault "workspace A";
  # In your config, you can drop workspace bindings that you don't need

  # See: https://nikitabobko.github.io/AeroSpace/commands#move-node-to-workspace
  services.aerospace.settings.mode.main.binding."${hyper}-1" =
    lib.mkDefault "move-node-to-workspace 1 --focus-follows-window";
  services.aerospace.settings.mode.main.binding."${hyper}-2" =
    lib.mkDefault "move-node-to-workspace 2 --focus-follows-window";
  services.aerospace.settings.mode.main.binding."${hyper}-3" =
    lib.mkDefault "move-node-to-workspace 3 --focus-follows-window";
  services.aerospace.settings.mode.main.binding."${hyper}-4" =
    lib.mkDefault "move-node-to-workspace 4 --focus-follows-window";
  services.aerospace.settings.mode.main.binding."${hyper}-5" =
    lib.mkDefault "move-node-to-workspace 5 --focus-follows-window";
  services.aerospace.settings.mode.main.binding."${hyper}-6" =
    lib.mkDefault "move-node-to-workspace 6 --focus-follows-window";
  services.aerospace.settings.mode.main.binding."${hyper}-7" =
    lib.mkDefault "move-node-to-workspace 7 --focus-follows-window";
  services.aerospace.settings.mode.main.binding."${hyper}-8" =
    lib.mkDefault "move-node-to-workspace 8 --focus-follows-window";
  services.aerospace.settings.mode.main.binding."${hyper}-9" =
    lib.mkDefault "move-node-to-workspace 9 --focus-follows-window";
  services.aerospace.settings.mode.main.binding."${hyper}-0" =
    lib.mkDefault "move-node-to-workspace A --focus-follows-window";

  # See: https://nikitabobko.github.io/AeroSpace/commands#workspace-back-and-forth
  services.aerospace.settings.mode.main.binding."${meh}-tab" =
    lib.mkDefault "workspace-back-and-forth";
  services.aerospace.settings.mode.main.binding."${hyper}-tab" =
    lib.mkDefault "move-workspace-to-monitor --wrap-around next";

  # See: https://nikitabobko.github.io/AeroSpace/commands#mode
  services.aerospace.settings.mode.main.binding."${hyper}-semicolon" = lib.mkDefault "mode service";

  # "service" binding mode declaration.
  # See: https://nikitabobko.github.io/AeroSpace/guide#binding-modes
  services.aerospace.settings.mode.service.binding.esc = lib.mkDefault [
    "reload-config"
    "mode main"
  ];
  # reset layout
  services.aerospace.settings.mode.service.binding.r = lib.mkDefault [
    "flatten-workspace-tree"
    "mode main"
  ];
  # Toggle between floating and tiling layout
  services.aerospace.settings.mode.service.binding.f = lib.mkDefault [
    "layout floating tiling"
    "mode main"
  ];
  services.aerospace.settings.mode.service.binding.backspace = lib.mkDefault [
    "close-all-windows-but-current"
    "mode main"
  ];

  # sticky is not yet supported https://github.com/nikitabobko/AeroSpace/issues/2
  #services.aerospace.settings.mode.service.binding.s = lib.mkDefault ["layout sticky tiling" "mode main"];

  services.aerospace.settings.mode.service.binding."${hyper}-h" = lib.mkDefault [
    "join-with left"
    "mode main"
  ];
  services.aerospace.settings.mode.service.binding."${hyper}-j" = lib.mkDefault [
    "join-with down"
    "mode main"
  ];
  services.aerospace.settings.mode.service.binding."${hyper}-k" = lib.mkDefault [
    "join-with up"
    "mode main"
  ];
  services.aerospace.settings.mode.service.binding."${hyper}-l" = lib.mkDefault [
    "join-with right"
    "mode main"
  ];

  services.aerospace.settings.mode.service.binding.down = lib.mkDefault "volume down";
  services.aerospace.settings.mode.service.binding.up = lib.mkDefault "volume up";
  services.aerospace.settings.mode.service.binding.shift-down = lib.mkDefault [
    "volume set 0"
    "mode main"
  ];
}
