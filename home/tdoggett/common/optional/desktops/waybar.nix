{
  pkgs,
  config,
  lib,
  homeModules,
  ...
}:

with lib;
{
  programs.waybar = {
    enable = lib.mkDefault true;
    systemd.enable = true;
    systemd.target = "graphical-session.target";

    settings = [
      {
        layer = "top";
        position = "top";
        exclusive = true;
        fixed-center = true;
        gtk-layer-shell = true;
        spacing = 0;
        margin-top = 0;
        margin-bottom = 0;
        margin-left = 0;
        margin-right = 0;

        modules-left = [
          "custom/nixlogo"
          "hyprland/workspaces"
          "hyprland/submap"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "hyprland/language"
          "tray"
          "pulseaudio"
          "cpu"
          "memory"
          "battery"
          "custom/notification"
        ];

        # Logo
        "custom/nixlogo" = {
          format = " ";
          tooltip = false;
          on-click = "${pkgs.wofi}/bin/wofi --show drun";
        };

        # Workspaces
        "hyprland/workspaces" = {
          format = "{name}";
          on-click = "activate";
          disable-scroll = true;
          # all-outputs = true;
          all-outputs = false;
          show-special = true;
        };

        # Submap Indicator
        "hyprland/submap" = {
          format = "{}";
          tooltip = false;
        };

        # Clock & Calendar
        clock = {
          format = "{:%a %b %d, %H:%M}";
          on-click = "${pkgs.eww}/bin/eww update showcalendar=true";

          actions = {
            on-scroll-down = "shift_down";
            on-scroll-up = "shift_up";
          };
        };

        # Tray
        tray = {
          icon-size = 18;
          show-passive-items = true;
          spacing = 8;
        };

        "hyprland/language" = {
          format = "{}";
          format-en = "US";
          format-el = "EL";
        };

        # Notifications
        "custom/notification" = {
          exec = "${pkgs.swaynotificationcenter}/bin/swaync-client -swb";
          return-type = "json";
          format = "{icon}";
          on-click = "${pkgs.swaynotificationcenter}/bin/swaync-client -t -sw";
          on-click-right = "${pkgs.swaynotificationcenter}/bin/swaync-client -d -sw";
          escape = true;

          format-icons = {
            notification = "󰂚";
            none = "󰂜";
            dnd-notification = "󰂛";
            dnd-none = "󰪑";
            inhibited-notification = "󰂛";
            inhibited-none = "󰪑";
            dnd-inhibited-notification = "󰂛";
            dnd-inhibited-none = "󰪑";
          };
        };

        # Pulseaudio
        pulseaudio = {
          format = "{volume} {icon} / {format_source}";
          format-source = "󰍬";
          format-source-muted = "󰍭";
          format-muted = "󰖁 / {format_source}";
          format-icons = {
            default = [
              "󰕿"
              "󰖀"
              "󰕾"
            ];
          };
          on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
          on-click-right = "${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
          on-scroll-up = "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +1%";
          on-scroll-down = "${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -1%";
          tooltip = false;
        };

        # Battery
        battery = {
          format = "{icon}  {capacity}%";
          format-charging = "{icon}  {capacity}%";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
          format-plugged = " {power} W";
          interval = 5;
          tooltip-format = "{timeTo}, {capacity}%\n {power} W";

          states = {
            warning = 30;
            critical = 15;
          };
        };

        # Cpu usage
        cpu = {
          interval = 5;
          tooltip = false;
          format = " {usage}%";
          format-alt = " {load}";

          states = {
            warning = 70;
            critical = 90;
          };
        };

        # Memory usage
        memory = {
          interval = 5;
          format = " {percentage}%";
          tooltip = " {used:0.1f}G/{total:0.1f}G";

          states = {
            warning = 70;
            critical = 90;
          };
        };
      }
    ];

    style = ''
      @define-color background-alt rgba(137, 180, 250, 0.05);
      @define-color background-focus rgba(255, 255, 255, 0.1);
      @define-color border rgba(205, 214, 244, 0.2);
      @define-color red rgb( 243, 139, 168);
      @define-color orange rgb( 250, 179, 135);
      @define-color yellow rgb( 249, 226, 175 );
      @define-color green rgb( 166, 227, 161 );
      @define-color blue rgb( 137, 180, 250 );
      @define-color gray rgb( 108, 112, 134 );
      @define-color black rgb( 49, 50, 68 );
      @define-color white rgb( 205, 214, 244 );

      * {
        all: unset;
        /* font:
          10pt "JetBrains Mono Nerd Font"*/
      }

      /* Button */
      button {
        box-shadow: inset 0 -0.25rem transparent;
        border: none;
      }

      button:hover {
        box-shadow: inherit;
        text-shadow: inherit;
      }

      /* Tooltip */
      tooltip {
        background: @base00;
        color: @base05;
        border: 1px solid @base03;
        border-radius: 5px;
      }

      tooltip label {
        margin: 0.5rem;
      }

      /*  Waybar window */
      window#waybar {
        background: @base00;
        /*border-radius: 7px;*/
      }

      /* Left Modules */
      .modules-left {
        padding-left: 0.5rem;
      }

      /* Right Modules */
      .modules-right {
        padding-right: 0.5rem;
      }

      /* Modules */
      #tray,
      #language,
      #pulseaudio,
      #cpu,
      #memory,
      #battery,
      #custom-notification,
      #clock {
        color: @base05;
        background: @base01;
        border: 1px solid @base03;
        border-radius: 5px;
        margin: 0.7rem 0.35rem;
        padding: 0.4rem 0.8rem 0.4rem 0.8rem;
      }

      #custom-nixlogo {
        color: @base05;
        background: @base01;
        border: 1px solid @base03;
        border-radius: 5px;
        margin: 0.7rem 0.35rem;
        padding: 0.4rem 0.45rem 0.4rem 0.7rem ;
        font: 10pt "JetBrains Mono Nerd Font";
      }

      .modules-left #workspaces button {
        border-bottom: 1px solid @base03;
      }
      .modules-left #workspaces button.focused,
      .modules-left #workspaces button.active {
        border-bottom: 1px solid @base03;
      }
      .modules-center #workspaces button {
        border-bottom: 1px solid @base03;
      }
      .modules-center #workspaces button.focused,
      .modules-center #workspaces button.active {
        border-bottom: 1px solid @base03;
      }
      .modules-right #workspaces button {
        border-bottom: 1px solid @base03;
      }
      .modules-right #workspaces button.focused,
      .modules-right #workspaces button.active {
        border-bottom: 1px solid @base03;
      }

      #workspaces button {
        background: @base01;
        color: @base05;
        border: 1px solid @base03;
        border-radius: 3px;
        padding: 0.4rem 0.8rem 0.4rem 0.8rem;
        margin-right: 0.8rem;
        margin: 0.7rem 0.35rem;
        transition: 200ms linear;
      }

      #workspaces button:last-child {
        margin-right: 0;
      }

      #workspaces button:hover {
        background: lighter(@base05);
        color: @black;
      }

      #workspaces button.empty {
        background: @base00;
        border: 1px solid @base03;
        color: @base05;
      }

      #workspaces button.empty:hover {
        background: lighter(@base03);
        color: @base05;
      }

      #workspaces button.urgent {
        background: @base08;
        color: @base05;
      }

      #workspaces button.urgent:hover {
        background: lighter(@base08);
        color: @base05;
      }

      #workspaces button.special {
        background: @base0A;
        color: @base05;
      }

      #workspaces button.special:hover {
        background: lighter(@base0A);
      }

      #workspaces button.active {
        background: @base0D;
        color: @black;
      }

      #workspaces button.active:hover {
        background: lighter(@base0D);
        color: @black;
      }

      #submap {
        background: @base08;
        color: @base05;
        border: 1px solid @base03;
        border-bottom: 3px solid @base03;
        border-radius: 3px;
        padding: 0.4rem 0.8rem 0.4rem 0.8rem;
        margin-right: 0;
        margin: 0.7rem 0.35rem;
        transition: 200ms linear;
      }

      /* Systray */
      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background: @base08;
      }

      menu {
        background: @base00;
        border: 1px solid @base03;
        border-radius: 8px;
      }

      menu separator {
        background: @base03;
      }

      menu menuitem {
        background: transparent;
        padding: 0.5rem;
        transition: 200ms;
      }

      menu menuitem:hover {
        background: @base02;
      }

      menu menuitem:first-child {
        border-radius: 8px 8px 0 0;
      }

      menu menuitem:last-child {
        border-radius: 0 0 8px 8px;
      }

      menu menuitem:only-child {
        border-radius: 8px;
      }

      /* Notification */
      #custom-notification {
        color: @base05;
      }

      #pulseaudio-slider highlight {
        background: @base05;
        border: 1px solid @base03;
      }

      /* Keyframes */
      @keyframes blink {
        to {
          color: @base05;
        }
      }
    '';
  };
}
