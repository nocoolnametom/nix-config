{ pkgs, lib, ... }:
{
  # Plymouth Boot Animation - Enhanced with animated themes
  # Shows a polished graphical boot screen instead of raw kernel messages

  environment.systemPackages = [ pkgs.adi1090x-plymouth-themes ];

  boot = {
    kernelParams = [
      "quiet" # Suppress kernel output before graphical boot
    ];

    plymouth = {
      enable = lib.mkDefault true;
      logo = lib.mkDefault "${pkgs.nixos-icons}/share/icons/hicolor/48x48/apps/nix-snowflake-white.png";
      theme = lib.mkForce "hexagon_hud";
      themePackages = [
        (pkgs.adi1090x-plymouth-themes.override { selected_themes = [ "hexagon_hud" ]; })
      ];
    };

    consoleLogLevel = 0; # Minimal console output
  };
}
