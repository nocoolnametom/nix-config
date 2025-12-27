{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # Enable the COSMIC login manager
  services.displayManager.cosmic-greeter.enable = true;

  # Enable the COSMIC desktop environment
  services.desktopManager.cosmic.enable = true;

  # Optional enhancements
  services.desktopManager.cosmic.xwayland.enable = lib.mkDefault true;
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = lib.mkDefault 1;

  # Remove Firefox theming to inherit from Cosmic
  programs.firefox.preferences."widget.gtk.libadwaita-colors.enabled" = false;
}
