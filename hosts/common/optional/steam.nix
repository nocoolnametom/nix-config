{ pkgs, lib, ... }:
{
  environment.systemPackages = with pkgs; [
    steam-run
  ];

  # Allow 32-bit OpenGL DRI support (for Steam!)
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  programs.steam.enable = lib.mkDefault true;
  programs.steam.extraCompatPackages = [
    # @TODO using the overlay until version 15 is added to unstable
    # pkgs.unstable.proton-ge-bin
    pkgs.proton-ge-bin-15
  ];
  programs.steam.localNetworkGameTransfers.openFirewall = true;
}
