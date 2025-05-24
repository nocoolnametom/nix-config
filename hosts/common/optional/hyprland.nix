{
  inputs,
  pkgs,
  configVars,
  ...
}:
let
  useInputs = builtins.hasAttr "hyprland" inputs;
in
{
  services.hypridle.enable = true;

  programs.hyprlock.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
    package = if (useInputs) then inputs.hyprland.packages.${pkgs.system}.hyprland else pkgs.hyprland;
    portalPackage =
      if (useInputs) then
        inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland
      else
        pkgs.xdg-desktop-portal-hyprland;
  };

  # Auto-login through Greetd and TuiGreet to Hyprland
  autoLogin.enable = true;
  autoLogin.username = configVars.username;

  environment.systemPackages = with pkgs; [
    lxqt.lxqt-policykit # Pop-up for GUI authentication in desktop
    xdg-desktop-portal-gtk
    (
      if (useInputs) then
        inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland
      else
        xdg-desktop-portal-hyprland
    )
  ];
}
