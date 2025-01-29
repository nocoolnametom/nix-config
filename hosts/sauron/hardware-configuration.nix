{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # include NixOS-WSL modules
    inputs.nixos-wsl.nixosModules.default
  ];

  wsl.enable = true;
  wsl.defaultUser = "tdoggett";
  wsl.extraBin = [
    {
      name = "bash";
      src = "${pkgs.bashInteractive}/bin/bash";
    }
  ];
  wsl.startMenuLaunchers = true;
  wsl.wslConf.automount.root = "/mnt";
  wsl.useWindowsDriver = true;
  # @TODO : Find a more-proper "nixos" way to do this!
  environment.sessionVariables.LD_LIBRARY_PATH = "/usr/lib/wsl/lib";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
