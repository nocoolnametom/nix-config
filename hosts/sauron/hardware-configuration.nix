{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    # include NixOS-WSL modules
    inputs.nixos-wsl.nixosModules.default
  ];

  wsl.enable = true;
  wsl.defaultUser = "tdoggett";
  wsl.extraBin = [{
    name = "bash";
    src = "${pkgs.bash}/bin/bash";
  }];
  wsl.startMenuLaunchers = true;
  wsl.wslConf.automount.root = "/mnt";

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}

