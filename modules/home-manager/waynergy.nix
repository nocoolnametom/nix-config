{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.waynergy;
  buildMap =
    map: offset:
    let
      buildLine = entry: "${toString entry.remote} = ${toString (entry.local - offset)} # ${entry.key}";
    in
    lib.concatMapStringsSep "\n" buildLine map;
  ergodoxmap = [
    {
      key = "A";
      remote = 1;
      local = 38;
    }
    {
      key = "B";
      remote = 12;
      local = 56;
    }
    {
      key = "C";
      remote = 9;
      local = 54;
    }
    {
      key = "D";
      remote = 3;
      local = 40;
    }
    {
      key = "E";
      remote = 15;
      local = 26;
    }
    {
      key = "F";
      remote = 4;
      local = 41;
    }
    {
      key = "G";
      remote = 6;
      local = 42;
    }
    {
      key = "H";
      remote = 5;
      local = 43;
    }
    {
      key = "I";
      remote = 35;
      local = 31;
    }
    {
      key = "J";
      remote = 39;
      local = 44;
    }
    {
      key = "K";
      remote = 41;
      local = 45;
    }
    {
      key = "L";
      remote = 38;
      local = 46;
    }
    {
      key = "M";
      remote = 47;
      local = 58;
    }
    {
      key = "N";
      remote = 46;
      local = 57;
    }
    {
      key = "O";
      remote = 32;
      local = 32;
    }
    {
      key = "P";
      remote = 36;
      local = 33;
    }
    {
      key = "Q";
      remote = 13;
      local = 24;
    }
    {
      key = "R";
      remote = 16;
      local = 27;
    }
    {
      key = "S";
      remote = 2;
      local = 39;
    }
    {
      key = "T";
      remote = 18;
      local = 28;
    }
    {
      key = "U";
      remote = 33;
      local = 30;
    }
    {
      key = "V";
      remote = 10;
      local = 55;
    }
    {
      key = "W";
      remote = 14;
      local = 25;
    }
    {
      key = "X";
      remote = 8;
      local = 53;
    }
    {
      key = "Y";
      remote = 17;
      local = 29;
    }
    {
      key = "Z";
      remote = 7;
      local = 52;
    }
    {
      key = "L_Shift";
      remote = 57;
      local = 50;
    }
    {
      key = "Escape";
      remote = 54;
      local = 9;
    }
    {
      key = "Backspace";
      remote = 52;
      local = 22;
    }
    {
      key = "Enter";
      remote = 37;
      local = 36;
    }
    {
      key = "Space";
      remote = 50;
      local = 65;
    }
    {
      key = "Tab";
      remote = 49;
      local = 23;
    }
    {
      key = "Delete";
      remote = 118;
      local = 119;
    }
    {
      key = ",";
      remote = 44;
      local = 59;
    }
    {
      key = ".";
      remote = 48;
      local = 60;
    }
    {
      key = "1";
      remote = 19;
      local = 10;
    }
    {
      key = "2";
      remote = 20;
      local = 11;
    }
    {
      key = "3";
      remote = 21;
      local = 12;
    }
    {
      key = "4";
      remote = 22;
      local = 13;
    }
    {
      key = "5";
      remote = 24;
      local = 14;
    }
    {
      key = "6";
      remote = 23;
      local = 15;
    }
    {
      key = "7";
      remote = 27;
      local = 16;
    }
    {
      key = "8";
      remote = 29;
      local = 17;
    }
    {
      key = "9";
      remote = 26;
      local = 18;
    }
    {
      key = "0";
      remote = 30;
      local = 19;
    }
    {
      key = "=";
      remote = 25;
      local = 21;
    }
    {
      key = "-";
      remote = 28;
      local = 20;
    }
    {
      key = "/";
      remote = 45;
      local = 61;
    }
    {
      key = "Application";
      remote = 111;
      local = 135;
    }
    {
      key = "Alt";
      remote = 59;
      local = 108;
    }
    {
      key = "Ctrl => Super";
      remote = 60;
      local = 133;
    }
    {
      key = "Super => Ctrl";
      remote = 56;
      local = 37;
    }
    {
      key = ";";
      remote = 42;
      local = 47;
    }
    {
      key = "'";
      remote = 40;
      local = 48;
    }
    {
      key = "[";
      remote = 34;
      local = 34;
    }
    {
      key = "]";
      remote = 31;
      local = 35;
    }
    {
      key = "\\";
      remote = 43;
      local = 51;
    }
    {
      key = "`";
      remote = 51;
      local = 49;
    }
    {
      key = "Left";
      remote = 124;
      local = 113;
    }
    {
      key = "Right";
      remote = 125;
      local = 114;
    }
    {
      key = "Up";
      remote = 127;
      local = 111;
    }
    {
      key = "Down";
      remote = 126;
      local = 116;
    }
    {
      key = "Home";
      remote = 116;
      local = 110;
    }
    {
      key = "End";
      remote = 120;
      local = 115;
    }
    {
      key = "PgUp";
      remote = 117;
      local = 112;
    }
    {
      key = "PgDn";
      remote = 122;
      local = 117;
    }
    {
      key = "F1";
      remote = 123;
      local = 67;
    }
    {
      key = "F2";
      remote = 121;
      local = 68;
    }
    {
      key = "F3";
      remote = 100;
      local = 69;
    }
    {
      key = "F4";
      remote = 119;
      local = 70;
    }
    {
      key = "F5";
      remote = 97;
      local = 71;
    }
    {
      key = "F6";
      remote = 98;
      local = 72;
    }
    {
      key = "F7";
      remote = 99;
      local = 73;
    }
    {
      key = "F8";
      remote = 101;
      local = 74;
    }
    {
      key = "F9";
      remote = 102;
      local = 75;
    }
    {
      key = "F10";
      remote = 110;
      local = 76;
    }
    {
      key = "F11";
      remote = 104;
      local = 95;
    }
    {
      key = "F12";
      remote = 112;
      local = 96;
    }
  ];
in
{
  options = {
    services.waynergy = {
      enable = lib.mkEnableOption "Whether to enable waynergy";

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to start waynergy on boot";
      };

      offset = lib.mkOption {
        type = lib.types.int;
        default = 7;
        description = "The offset to apply to the keymap";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "192.168.1.132";
        description = "The host to connect to";
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = 24801;
        description = "The port to connect to";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."waynergy/xkb_keymap".text = ''
      xkb_keymap {
        xkb_keycodes  { include "evdev+aliases(qwerty)" };
        xkb_types     { include "complete"      };
        xkb_compat    { include "complete"      };
        xkb_symbols   { include "pc+us+inet(evdev)" };
        xkb_geometry  { include "pc(pc105)"      };
      };
    '';
    xdg.configFile."waynergy/config.ini".text =
      (lib.generators.toINIWithGlobalSection { } {
        globalSection = {
          host = cfg.host;
          port = "${toString cfg.port}";
          xkb_key_offset = "${toString cfg.offset}";
          name = osConfig.networking.hostName;
          # width = 1024;
          # height = 768;
          # restart_on_fatal = false;
        };
        sections = {
          idle-inhibit = {
            method = "key";
            keyname = "HYPR";
          };
          tls = {
            enable = true;
            tofu = true;
          };
          log = {
            level = "3";
            mode = "a";
            path = "/tmp/waynergy.log";
          };
          wayland = {
            #flush_timeout = 5000
          };
        };
      })
      + "\n"
      + ''
        [raw-keymap]
        ${buildMap ergodoxmap cfg.offset}
      '';

    systemd.user.services.waynergy = {
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };

      Unit = {
        Description = "Waynergy Client";
        After = [
          "network.target"
          "graphical-session-pre.target"
        ];
        PartOf = if cfg.autoStart then [ "graphical-session.target" ] else [ ];
        X-Restart-Triggers = [ "${config.xdg.configFile."waynergy/config.ini".source}" ];
      };

      Service = {
        ExecStart = "${pkgs.waynergy}/bin/waynergy -p ${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
