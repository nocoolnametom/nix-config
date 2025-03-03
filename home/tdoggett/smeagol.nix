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
    common/optional/services/ssh-agent.nix
    common/optional/sops.nix
    common/optional/git.nix
  ];

  programs.git.userEmail = configVars.gitHubEmail;

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
