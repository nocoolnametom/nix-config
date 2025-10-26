{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  services.desktopManager.cosmic.enable = lib.mkDefault true;
  services.desktopManager.cosmic.xwayland.enable = lib.mkDefault true;
  services.displayManager.cosmic-greeter.enable = lib.mkDefault true;
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = lib.mkDefault 1;

  # Ensure other Desktop Environments are off
  services.greetd.enable = lib.mkForce false;

  # Remove Firefox theming to inherit from Cosmic
  programs.firefox.preferences."widget.gtk.libadwaita-colors.enabled" = false;
}
