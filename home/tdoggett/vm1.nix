{
  pkgs,
  lib,
  config,
  configVars,
  osConfig,
  inputs,
  ...
}:
{
  imports = [
    ########################## Required Configs ###########################
    common/core # required - remember to include a sops config below!

    #################### Host-specific Optional Configs ####################
    common/optional/only-hm.nix # Extra configs for systems ONLY using HM
    common/optional/sops-work.nix # used instead of sops.nix!
    common/optional/ssh-work.nix
    common/optional/git.nix
    common/optional/devenv.nix
  ];

  programs.git.userEmail = configVars.email.work;

  # Custom packages are already overlaid into the provided `pkgs`
  home.packages = with pkgs; [
  ];

  home = {
    stateVersion = "24.11";
    username = configVars.username;
    homeDirectory = lib.mkForce "/home/${configVars.username}";
    sessionVariables.TERM = lib.mkForce "xterm-256color";
    sessionVariables.TERMINAL = lib.mkForce "";
  };
}
