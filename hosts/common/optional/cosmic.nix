{ inputs, lib, ... }:
{
  imports = [ inputs.nixos-cosmic.nixosModules.default ];

  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # Ensure other Desktop Environments are off
  services.greetd.enable = lib.mkForce false;
  programs.hyprlock.enable = lib.mkForce false;
  programs.hyprland.enable = lib.mkForce false;
  programs.sway.enable = lib.mkForce false;
  services.xserver.desktopManager.plasma5.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;
  services.displayManager.sddm.enable = lib.mkForce false;
}
