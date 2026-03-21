{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  # Stylix modules are loaded in the core/default.nix and
  # darwin/core/default.nix files

  # Home Manager integration is handled via sharedModules in core configs
  stylix.homeManagerIntegration.autoImport = false;
  stylix.homeManagerIntegration.followSystem = false;

  # Stylix - System-wide theming via Home Manager
  # Base configuration that can be overridden per-host
  stylix.enable = lib.mkDefault true;
  stylix.autoEnable = lib.mkDefault true;

  # Font defaults
  stylix.fonts.serif.package = pkgs.appleFonts.sf-pro;
  stylix.fonts.serif.name = "SFProText Nerd Font";
  stylix.fonts.sansSerif.package = pkgs.appleFonts.sf-pro;
  stylix.fonts.sansSerif.name = "SFProDisplay Nerd Font";
  stylix.fonts.monospace.package = pkgs.appleFonts.sf-mono;
  stylix.fonts.monospace.name = "SFMono Nerd Font";
  stylix.fonts.emoji.package = lib.mkDefault pkgs.noto-fonts-color-emoji;
  stylix.fonts.emoji.name = lib.mkDefault "Noto Color Emoji";
}
// (lib.mkIf pkgs.stdenv.isLinux {
  # Cursor theme - Can't change this on Darwin
  stylix.cursor.package = lib.mkDefault pkgs.phinger-cursors;
  stylix.cursor.name = lib.mkDefault "phinger-cursors-light";
  stylix.cursor.size = lib.mkDefault 24;

  # I tend to use dark themes on Linux machines
  stylix.polarity = lib.mkDefault "dark";
  stylix.base16Scheme = lib.mkDefault "${inputs.stylix.inputs.tinted-schemes}/base16/catppuccin-mocha.yaml";
})
// (lib.mkIf pkgs.stdenv.isDarwin {
  # I tend to use light themes on Darwin machines
  stylix.polarity = lib.mkDefault "light";
  stylix.base16Scheme = lib.mkDefault "${inputs.stylix.inputs.tinted-schemes}/base16/catppuccin-latte.yaml";
})
