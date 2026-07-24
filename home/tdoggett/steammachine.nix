{
  lib,
  config,
  configVars,
  osConfig,
  inputs,
  pkgs ? inputs.nixpkgs,
  ...
}:
{
  imports = [
    ########################## Required Configs ###########################
    common/core # required - remember to include a sops config below!

    #################### Host-specific Optional Configs ####################
    common/optional/only-hm.nix # Extra configs for systems ONLY using HM
    common/optional/steamos-hm-helper.nix # PATH ordering fix for Steam on SteamOS
    common/optional/sops.nix
    common/optional/git.nix
    common/optional/jj.nix
    common/optional/devenv.nix
    common/optional/desktops/brave.nix
    common/optional/desktops/kitty.nix
    common/optional/desktops/vscode.nix
    common/optional/wakatime.nix
  ];

  home.packages = with pkgs; [
    helium-browser-flake
  ];

  programs.git.settings.user.email = configVars.gitHubEmail;

  services.yubikey-touch-detector.enable = true;

  home = {
    stateVersion = "26.05";
    username = lib.mkForce "deck";
    homeDirectory = lib.mkForce "/home/deck";
    sessionVariables.TERM = lib.mkForce "xterm-256color";
    sessionVariables.TERMINAL = lib.mkForce "";
  };
}
