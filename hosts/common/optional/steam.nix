{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    steam
    steam-run
  ];

  # Allow 32-bit OpenGL DRI support (for Steam!)
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  programs.steam.enable = lib.mkDefault true;
  programs.steam.extraCompatPackages = [
    pkgs.proton-ge-bin
  ];
  programs.steam.localNetworkGameTransfers.openFirewall = true;
}
