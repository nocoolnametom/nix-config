{ pkgs, ... }:
{
  # Plymouth Boot Animation
  boot.plymouth.enable = true;
  boot.plymouth.logo = "${pkgs.nixos-icons}/share/icons/hicolor/48x48/apps/nix-snowflake-white.png";
  boot.plymouth.theme = "hexagon_hud";
  boot.plymouth.themePackages = [
    (pkgs.adi1090x-plymouth-themes.override {
      selected_themes = [
        "black_hud"
        "circle_hud"
        "hexagon_hud"
        "square_hud"
      ];
    })
  ];
}
