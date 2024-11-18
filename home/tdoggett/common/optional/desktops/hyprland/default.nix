{
  inputs,
  pkgs,
  config,
  ...
}:

{
  imports = [
    ./binds.nix
    ./exec-once.nix
  ];
  # Hyprland
  wayland.windowManager.hyprland = {
    systemd.enable = true;
    plugins = [
      pkgs.unstable.hyprlandPlugins.hypr-dynamic-cursors # In unstable, not 24.05
      pkgs.unstable.hyprlandPlugins.hy3
      # inputs.split-monitor-workspaces.packages.${pkgs.system}.split-monitor-workspaces # TODO Broken as of 2024-11-12
    ];
    settings = {
      # Monitors - Remember to define system-specific ones explicity in home/<user>/<host>/default.nix!
      monitor = [
        # "name,resolution,position,scale"
        ",preferred,auto-left,1" # Fallback rule for other screens
      ];

      # Environment Variables
      env = [
        "XCURSOR_SIZE,16"
        "HYPRCURSOR_SIZE,16"
      ];

      # Dynamic Cursors
      "plugin:dynamic-cursors" = {
        enabled = true;
        mode = "tilt"; # tilt, rotate, stretch, none
        threshold = 2;
        tilt = {
          limit = 5000; # Lower is more powerful
          function = "quadratic"; # linear, quadratic, negative_quadratic
        };
        shake = {
          enabled = true;
          threshold = 4.0;
          factor = 1.5;
          effects = false; # Show effects while expanding during shake
          nearest = true;
          ipc = false;
        };
      };

      "plugin:split-monitor-workspaces" = {
        # TODO: This broke on 12-Nov-2024, maybe it's working again now?
        enabled = false;
        count = 5;
      };

      # Look and Feel
      general = {
        gaps_in = "5";
        gaps_out = "5";

        border_size = "2";

        # Set to true enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = "true";

        # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
        allow_tearing = "false";

        layout = "hy3"; # dwindle, hy3
      };

      # Some decoration is handled by the stylix module
      decoration = {
        rounding = "5";

        # Change transparency of focused and unfocused windows
        active_opacity = "1.0";
        inactive_opacity = "0.95";

        drop_shadow = "true";
        shadow_range = "4";
        shadow_render_power = "3";

        # https://wiki.hyprland.org/Configuring/Variables/#blur
        blur = {
          enabled = "true";
          size = "3";
          passes = "1";

          vibrancy = "0.1696";
        };
      };

      animations = {
        enabled = "true";

        # Default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more

        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";

        animation = [
          # name,       onoff, speed, curve,   [style]
          "windows,     1,     2,     myBezier"
          "windowsOut,  1,     2,     default, popin 80%"
          "border,      1,     5,     default"
          "borderangle, 1,     3,     default"
          "fade,        1,     2,     default"
          "workspaces,  1,     1,     default"
        ];
      };

      dwindle = {
        no_gaps_when_only = "1";
        pseudotile = "true"; # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        preserve_split = "true"; # You probably want this
      };

      "plugin:hy3" = {
        enabled = true;
        no_gaps_when_only = "1";
        group_inset = "5";
      };

      master = {
        new_status = "master";
      };

      misc = {
        force_default_wallpaper = "-1"; # Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo = "false"; # If true disables the random hyprland logo / anime girl background. :(
      };

      # Input
      input = {
        kb_layout = "us";
        kb_variant = "";
        kb_model = "";
        kb_options = "";
        kb_rules = "";

        follow_mouse = "1";

        sensitivity = "0"; # -1.0 - 1.0, 0 means no modification.

        touchpad = {
          natural_scroll = "false";
        };
      };

      gestures = {
        workspace_swipe = "false";
      };

      device = {
        name = "epic-mouse-v1";
        sensitivity = "-0.5";
      };

      # Windows and Workspaces
      windowrulev2 = "suppressevent maximize, class:.*"; # You'll probably like this.
    };
  };
}
