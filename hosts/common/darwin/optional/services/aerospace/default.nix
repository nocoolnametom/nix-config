{ lib, config, ... }:
let
  sketchybarCfg = config.services.sketchybar;
  sketchybar =
    if sketchybarCfg.enable then "${sketchybarCfg.package}/bin/sketchybar" else "sketchybar";
  hyper = "alt-ctrl-shift-cmd";
  meh = "alt-ctrl-shift";

  # Mode transition helpers. Aerospace doesn't fire any built-in event on mode
  # change, so every `mode X` command must be paired with a sketchybar trigger
  # to keep the on-screen indicator in sync. See:
  # hosts/common/darwin/optional/services/sketchybar/plugins/aerospace_mode.nix
  triggerMode = name: "exec-and-forget ${sketchybar} --trigger aerospace_mode_change MODE=${name}";
  toMode = name: [
    "mode ${name}"
    (triggerMode name)
  ];
  toMain = toMode "main";
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
  services.aerospace.settings.automatically-unhide-macos-hidden-apps = lib.mkDefault true;

  services.aerospace.settings.on-window-detected = lib.mkDefault (
    [
      {
        # Float the file finder
        "if" = {
          app-name-regex-substring = "Finder";
        };
        run = [ "layout floating" ];
      }
      {
        # Float iTerm updater window popup
        "if" = {
          window-title-regex-substring = "Updating iTerm";
        };
        run = [ "layout floating" ];
      }
      {
        # Float the MAIN Apple Music window, but NOT the miniplayer!
        "if" = {
          app-id = "com.apple.Music";
          window-title-regex-substring = "(Music|Activity|Equalizer)";
        };
        run = [ "layout floating" ];
      }
      {
        # Float Kepper login SSO window
        "if" = {
          app-id = "com.callpod.keepermac.lite";
          window-title-regex-substring = "- Sign In";
        };
        run = [ "layout floating" ];
      }
    ]
    # Float these apps by default
    ++ (builtins.map
      (app_id: {
        "if" = {
          app-id = app_id;
        };
        run = [ "layout floating" ];
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
        # Corporate VPN client (main window)
        "com.cisco.secureclient.gui"
        # Corporate VPN client (socket filter)
        "com.cisco.anyconnect.macos.acsock"
        # Corporate VPN client (diagnostic / DART)
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
  # - Per monitor:  gaps.outer.top = [{ monitor.main = 16 } { monitor."some-pattern" = 32 } 24]
  #                 In this example, 24 is a default value when there is no match.
  #                 Monitor pattern is the same as for "workspace-to-monitor-force-assignment".
  #                 See:
  #                 https://nikitabobko.github.io/AeroSpace/guide#assign-workspaces-to-monitors
  services.aerospace.settings.gaps.inner.horizontal = lib.mkDefault 4;
  services.aerospace.settings.gaps.inner.vertical = lib.mkDefault 4;
  services.aerospace.settings.gaps.outer.left = lib.mkDefault 4;
  services.aerospace.settings.gaps.outer.bottom = lib.mkDefault 4;
  services.aerospace.settings.gaps.outer.top = lib.mkDefault [
    { monitor."built-in" = 0; }
    33
  ];
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
  services.aerospace.settings.mode.main.binding."${meh}-h" = lib.mkDefault "focus left";
  services.aerospace.settings.mode.main.binding."${meh}-j" = lib.mkDefault "focus down";
  services.aerospace.settings.mode.main.binding."${meh}-k" = lib.mkDefault "focus up";
  services.aerospace.settings.mode.main.binding."${meh}-l" = lib.mkDefault "focus right";

  # See: https://nikitabobko.github.io/AeroSpace/commands#move
  services.aerospace.settings.mode.main.binding."${hyper}-h" = lib.mkDefault "move left";
  services.aerospace.settings.mode.main.binding."${hyper}-j" = lib.mkDefault "move down";
  services.aerospace.settings.mode.main.binding."${hyper}-k" = lib.mkDefault "move up";
  services.aerospace.settings.mode.main.binding."${hyper}-l" = lib.mkDefault "move right";

  # Fullscreen toggle stays in main (one-shot action, no need for a mode).
  # The resize bindings moved into `alter` mode so you can chain repeats with
  # bare keys (-/=) rather than holding the meh modifier each press.
  services.aerospace.settings.mode.main.binding."${meh}-f" = lib.mkDefault "fullscreen";

  # See: https://nikitabobko.github.io/AeroSpace/commands#workspace
  services.aerospace.settings.mode.main.binding."${meh}-left" = lib.mkDefault "workspace prev";
  services.aerospace.settings.mode.main.binding."${meh}-right" = lib.mkDefault "workspace next";
  services.aerospace.settings.mode.main.binding."${meh}-up" = lib.mkDefault "focus-monitor prev";
  services.aerospace.settings.mode.main.binding."${meh}-down" = lib.mkDefault "focus-monitor next";
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
  # Entry points into the non-`main` modes. Both fire the sketchybar mode-change
  # trigger via `toMode` so the bar widget updates in lockstep with aerospace.
  services.aerospace.settings.mode.main.binding."${hyper}-a" = lib.mkDefault (toMode "alter");
  services.aerospace.settings.mode.main.binding."${hyper}-semicolon" = lib.mkDefault (
    toMode "service"
  );
  # Plain exit of non-main modes
  services.aerospace.settings.mode.service.binding.esc = lib.mkDefault toMain;
  services.aerospace.settings.mode.alter.binding.esc = lib.mkDefault toMain;

  # ───────────────────────────────────────────────────────────────────────────
  # "alter" binding mode — window-tree / layout / destructive operations.
  # Visual indicator: amber bar in sketchybar (see plugins/aerospace_mode.nix).
  # ───────────────────────────────────────────────────────────────────────────

  # Reset layout (flatten the workspace tree to a single horizontal row)
  services.aerospace.settings.mode.alter.binding.r = lib.mkDefault ([ "flatten-workspace-tree" ]);

  # Toggle between floating and tiling layout for the focused window
  services.aerospace.settings.mode.alter.binding.f = lib.mkDefault ([ "layout floating tiling" ]);

  # Combine the focused window into a subgroup with its neighbor on the given
  # side — the primary way to build nested column/row layouts.
  services.aerospace.settings.mode.alter.binding.h = lib.mkDefault ([ "join-with left" ]);
  services.aerospace.settings.mode.alter.binding.j = lib.mkDefault ([ "join-with down" ]);
  services.aerospace.settings.mode.alter.binding.k = lib.mkDefault ([ "join-with up" ]);
  services.aerospace.settings.mode.alter.binding.l = lib.mkDefault ([ "join-with right" ]);

  # Resize the focused window. Bare keys (no modifier) so you can chain
  # presses: enter alter once, then `-----` or `=====` to shrink/grow. Stays
  # in alter mode after each press — exit with `esc`.
  services.aerospace.settings.mode.alter.binding.minus = lib.mkDefault "resize smart -50";
  services.aerospace.settings.mode.alter.binding.equal = lib.mkDefault "resize smart +50";

  # sticky is not yet supported https://github.com/nikitabobko/AeroSpace/issues/2
  # services.aerospace.settings.mode.alter.binding.s = lib.mkDefault (["layout sticky tiling"] ++ toMain);

  # ───────────────────────────────────────────────────────────────────────────
  # "service" binding mode — admin / system tasks (reload-config + volume).
  # Visual indicator: blue bar in sketchybar.
  # Exits: `esc` (no-op exit), `r` (reload + exit), `shift-down` (mute + exit).
  # ───────────────────────────────────────────────────────────────────────────

  # Reload the aerospace config (picks up any changes since last load).
  # Exits to main after reloading.
  services.aerospace.settings.mode.service.binding.r = lib.mkDefault ([ "reload-config" ] ++ toMain);

  # Volume — stay in service mode for up/down so you can hold the key; mute
  # (shift-down) exits to main.
  services.aerospace.settings.mode.service.binding.down = lib.mkDefault "volume down";
  services.aerospace.settings.mode.service.binding.up = lib.mkDefault "volume up";
  services.aerospace.settings.mode.service.binding.shift-down = lib.mkDefault (
    [ "volume set 0" ] ++ toMain
  );
}
