{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    alvr
  ];

  programs.steam.remotePlay.openFirewall = lib.mkDefault true; # Open ports in the firewall for Steam Remote Play
  programs.steam.dedicatedServer.openFirewall = lib.mkDefault true; # Open ports in the firewall for Source Dedicated Server

  programs.alvr.enable = lib.mkDefault true;
  programs.alvr.openFirewall = lib.mkDefault true;

  xdg.portal.enable = lib.mkDefault true;
  xdg.portal.xdgOpenUsePortal = lib.mkDefault true;
}
