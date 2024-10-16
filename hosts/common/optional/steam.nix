{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    steam
    steam-run
  ];

  # Allow 32-bit OpenGL DRI support (for Steam!)
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
