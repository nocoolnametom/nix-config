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
    # pkgs.bleeding.proton-ge-bin # For using master branch
    # pkgs.unstable.proton-ge-bin # For using unstable branch
  ];
  programs.steam.localNetworkGameTransfers.openFirewall = true;
}
