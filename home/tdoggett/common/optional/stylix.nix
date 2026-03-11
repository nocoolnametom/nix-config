{ pkgs, lib, ... }:
{
  # Stylix - System-wide theming via Home Manager
  # Base configuration that can be overridden per-host
  stylix.enable = lib.mkDefault true;
  stylix.polarity = lib.mkDefault "dark";

  # Default color scheme — github-dark is a neutral dark theme that works well everywhere.
  # Override this in a host's home file to use a different scheme.
  stylix.base16Scheme = lib.mkDefault "${pkgs.base16-schemes}/share/themes/github-dark.yaml";

  # Cursor theme
  stylix.cursor.package = lib.mkDefault pkgs.phinger-cursors;
  stylix.cursor.name = lib.mkDefault "phinger-cursors-light";
  stylix.cursor.size = lib.mkDefault 24;

  # Font defaults
  stylix.fonts.serif.package = lib.mkDefault pkgs.dejavu_fonts;
  stylix.fonts.serif.name = lib.mkDefault "DejaVu Serif";
  stylix.fonts.sansSerif.package = lib.mkDefault pkgs.dejavu_fonts;
  stylix.fonts.sansSerif.name = lib.mkDefault "DejaVu Sans";
  stylix.fonts.monospace.package = lib.mkDefault pkgs.dejavu_fonts;
  stylix.fonts.monospace.name = lib.mkDefault "DejaVu Sans Mono";
  stylix.fonts.emoji.package = lib.mkDefault pkgs.noto-fonts-color-emoji;
  stylix.fonts.emoji.name = lib.mkDefault "Noto Color Emoji";
}
