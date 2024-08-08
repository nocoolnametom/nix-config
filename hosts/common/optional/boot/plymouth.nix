{ pkgs, ... }:
{
  # Plymouth Boot Animation
  boot.plymouth.enable = true;
  boot.plymouth.theme = "rings";
  boot.plymouth.themePackages = [
    (pkgs.adi1090x-plymouth-themes.override { selected_themes = [ "rings" ]; })
  ];
}
