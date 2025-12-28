{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # include NixOS-WSL modules, currently commented out in main flake.nix
    # inputs.nixos-wsl.nixosModules.default
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
  wsl.interop.register = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
