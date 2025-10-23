{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  # imports = [ inputs.nixos-cosmic.nixosModules.default ];

  services.desktopManager.cosmic.enable = lib.mkDefault true;
  services.displayManager.cosmic-greeter.enable = lib.mkDefault true;
  environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = lib.mkDefault 1;
  # systemd.packages = [ pkgs.observatory ];
  # systemd.services.monitord.wantedBy = [ "multi-user.target" ];

  # Ensure other Desktop Environments are off
  services.greetd.enable = lib.mkForce false;
  programs.hyprlock.enable = lib.mkForce false;
  programs.hyprland.enable = lib.mkForce false;
}
