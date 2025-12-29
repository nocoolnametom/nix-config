{ lib, pkgs, ... }:
{
  virtualisation.podman.enable = lib.mkDefault true;
  virtualisation.podman.dockerCompat = true;
  environment.systemPackages = [
    pkgs.distrobox
  ];
}
