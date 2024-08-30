{ pkgs, ... }:
{
  services.hypridle.enable = true;

  programs.hyprlock.enable = true;

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland; # default
  };

  # Auto-login through Greetd and TuiGreet to Hyprland
  autoLogin.enable = true;
  autoLogin.username = "tdoggett";

  environment.systemPackages = with pkgs; [
    lxqt.lxqt-policykit # Pop-up for GUI authentication in desktop
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
  ];
}
