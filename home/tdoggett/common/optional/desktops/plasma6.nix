{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

let
  largeDellMonitorId = "136a0a5c-2382-5b5f-95ea-4daa2dfdf9dd";
  topPanel = screenNum: {
    screen = screenNum;
    floating = true;
    location = "top";
    hiding = "none";
    alignment = "left";
    height = 27;
    widgets = [
      "org.kde.plasma.analogclock"
      "org.kde.plasma.appmenu"
    ];
  };
  bottomPanel = screenNum: {
    screen = screenNum;
    height = 44;
    floating = true;
    hiding = "dodgewindows";
    location = "bottom";
    widgets = [
      {
        name = "org.kde.plasma.kickoff";
        config.General.icon = "nix-snowflake-white";
      }
      {
        name = "org.kde.plasma.icontasks";
        config.General.launchers = [
          "applications:systemsettings.desktop"
          "applications:org.kde.dolphin.desktop"
          "applications:org.kde.konsole.desktop"
          "applications:google-chrome.desktop"
          "applications:firefox.desktop"
          "applications:brave-browser.desktop"
        ];
        config.General.showOnlyCurrentScreen = "true";
      }
      "org.kde.plasma.marginsseparator"
      "org.kde.plasma.systemtray"
      {
        digitalClock.calendar.firstDayOfWeek = "sunday";
        digitalClock.time.format = "12h";
      }
    ];
  };
in
{

  imports = [ inputs.plasma-manager.homeManagerModules.plasma-manager ];

  programs.plasma = {
    enable = true;

    # Not sure if I need this, but it popped up in the diff
    shortcuts."ksmserver"."_k_friendly_name" = "Session Management";

    workspace.lookAndFeel = "org.kde.breezedark.desktop";
    workspace.theme = "breeze-dark";
    workspace.colorScheme = "BreezeDark";
    workspace.cursor.theme = "breeze_cursors";

    panels = [
      (topPanel 0)
      (bottomPanel 0)
      (topPanel 1)
      (bottomPanel 1)
    ];

    #
    # Some low-level settings:
    #
    configFile = {
      # Prevent auto-indexing of files, I can use CLI tools for this
      baloofilerc."Basic Settings"."Indexing-Enabled" = false;

      # Dark Breeze Theme 
      kdeglobals."WM"."activeBackground" = "49,54,59";
      kdeglobals."WM"."activeBlend" = "252,252,252";
      kdeglobals."WM"."activeForeground" = "252,252,252";
      kdeglobals."WM"."inactiveBackground" = "42,46,50";
      kdeglobals."WM"."inactiveBlend" = "161,169,177";
      kdeglobals."WM"."inactiveForeground" = "161,169,177";

      # Not sure if I need this
      krunnerrc."Plugins"."baloosearchEnabled" = false;

      # KWin
      kwinrc."Effect-windowview"."BorderActivateClass" = 3;
      kwinrc."NightColor"."Active" = true;
      kwinrc."NightColor"."LatitudeAuto" = 42.44;
      kwinrc."NightColor"."LongitudeAuto" = "-76.49";
      kwinrc."Tiling/${largeDellMonitorId}"."tiles" = "{\"layoutDirection\":\"horizontal\",\"tiles\":[{\"width\":0.25},{\"width\":0.5},{\"width\":0.25}]}";

      # Scaling
      kdeglobals."KScreen"."ScaleFactor" = 1.0;
      kwinrc."Xwayland"."Scale" = 1.0;

      plasmarc."Wallpapers"."usersWallpapers" = "";
    };
  };
}
