{
  inputs,
  pkgs,
  configVars,
  ...
}:
{
  services.hypridle.enable = true;

  programs.hyprlock.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
  };

  # Auto-login through Greetd and TuiGreet to Hyprland
  autoLogin.enable = true;
  autoLogin.username = configVars.username;

  environment.systemPackages = with pkgs; [
    lxqt.lxqt-policykit # Pop-up for GUI authentication in desktop
    inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
  ];
}
