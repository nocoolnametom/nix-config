{
  programs.waybar = {
    systemd.enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      spacing = 0;
      height = 30;
      modules-left = [
        "custom/logo"
        "hyprland/workspaces"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "memory"
        "pulseaudio"
        "battery"
        "custom/power"
      ];
      "wlr/taskbar" = {
        format = "{icon}";
        on-click = "activate";
        on-click-right = "fullscreen";
        icon-theme = "WhiteSur";
        icon-size = 25;
        tooltip-format = "{title}";
      };
      "hyprland/workspaces" = {
        on-click = "activate";
        format = "{icon}";
        format-icons = {
          default = "";
          "1" = "1";
          "2" = "2";
          "3" = "3";
          "4" = "4";
          "5" = "5";
          "6" = "6";
          "7" = "7";
          "8" = "8";
          "9" = "9";
          active = "󱓻";
          urgent = "󱓻";
        };
        persistent_workspaces = {
          "1" = [ ];
          "2" = [ ];
          "3" = [ ];
          "4" = [ ];
          "5" = [ ];
        };
      };
      memory = {
        interval = 5;
        format = "󰍛 {}%";
        max-length = 10;
      };
      tray = {
        spacing = 10;
      };
      clock = {
        tooltip-format = "{calendar}";
        format-alt = "  {:%a, %d %b %Y}";
        format = "⏲  {:%I:%M %p}";
      };
      pulseaudio = {
        format = "{icon}";
        format-bluetooth = "󰂰";
        nospacing = 1;
        tooltip-format = "Volume : {volume}%";
        format-muted = "󰝟";
        format-icons = {
          headphone = "";
          default = [
            "󰖀"
            "󰕾"
            ""
          ];
        };
        on-click = "pamixer -t";
        scroll-step = 1;
      };
      "custom/logo" = {
        format = "  ";
        tooltip = false;
      };
      battery = {
        format = "{capacity}% {icon}";
        format-icons = {
          charging = [
            "󰢜"
            "󰂆"
            "󰂇"
            "󰂈"
            "󰢝"
            "󰂉"
            "󰢞"
            "󰂊"
            "󰂋"
            "󰂅"
          ];
          default = [
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
        };
        format-full = "Charged ";
        interval = 5;
        states = {
          warning = 20;
          critical = 10;
        };
        tooltip = false;
      };
      "custom/power" = {
        format = "󰤆";
        tooltip = false;
      };
    };
    # TODO Some of this might be better handled with Stylix
    style = ''
      * {
        border: none;
        border-radius: 0;
        min-height: 0;
        font-family: JetBrainsMono Nerd Font;
        font-size: 13px;
      }

      window#waybar {
        background-color: #181825;
        transition-property: background-color;
        transition-duration: 0.5s;
      }

      window#waybar.hidden {
        opacity: 0.5;
      }

      #workspaces {
        background-color: transparent;
      }

      #workspaces button {
        all: initial;
        /* Remove GTK theme values (waybar #1351) */
        min-width: 0;
        /* Fix weird spacing in materia (waybar #450) */
        box-shadow: inset 0 -3px transparent;
        /* Use box-shadow instead of border so the text isn't offset */
        padding: 6px 18px;
        margin: 6px 3px;
        border-radius: 4px;
        background-color: #1e1e2e;
        color: #cdd6f4;
      }

      #workspaces button.active {
        color: #1e1e2e;
        background-color: #cdd6f4;
      }

      #workspaces button:hover {
        box-shadow: inherit;
        text-shadow: inherit;
        color: #1e1e2e;
        background-color: #cdd6f4;
      }

      #workspaces button.urgent {
        background-color: #f38ba8;
      }

      #memory,
      #custom-power,
      #battery,
      #backlight,
      #pulseaudio,
      #network,
      #clock,
      #tray {
        border-radius: 4px;
        margin: 6px 3px;
        padding: 6px 12px;
        background-color: #1e1e2e;
        color: #181825;
      }

      #custom-power {
        margin-right: 6px;
      }

      #custom-logo {
        padding-right: 7px;
        padding-left: 7px;
        margin-left: 5px;
        font-size: 15px;
        border-radius: 8px 0px 0px 8px;
        color: #1793d1;
      }

      #memory {
        background-color: #fab387;
      }

      #battery {
        background-color: #f38ba8;
      }

      #battery.warning,
      #battery.critical,
      #battery.urgent {
        background-color: #ff0000;
        color: #FFFF00;
      }

      #battery.charging {
        background-color: #a6e3a1;
        color: #181825;
      }

      #backlight {
        background-color: #fab387;
      }

      #pulseaudio {
        background-color: #f9e2af;
      }

      #network {
        background-color: #94e2d5;
        padding-right: 17px;
      }

      #clock {
        font-family: JetBrainsMono Nerd Font;
        background-color: #cba6f7;
      }

      #custom-power {
        background-color: #f2cdcd;
      }

      tooltip {
        border-radius: 8px;
        padding: 15px;
        background-color: #131822;
      }

      tooltip label {
        padding: 5px;
        background-color: #131822;
      }
    '';
  };
}
