{ lib, config, configVars, ... }: {
  programs.nh.enable = lib.mkDefault true;
  programs.nh.clean.enable = lib.mkDefault true;
  programs.nh.flake = lib.mkDefault "${config.home.homeDirectory}/Projects/${configVars.username}/nix-config";
}
