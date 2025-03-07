{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    alvr
  ];

  programs.steam.remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
  programs.steam.dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server

  programs.alvr.enable = lib.mkDefault true;
  programs.alvr.openFirewall = lib.mkDefault true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
  };
}
