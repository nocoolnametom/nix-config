{ pkgs, lib, ... }:
{
  yubikey = {
    enable = lib.mkDefault true;
    identifiers = {
      ykbackup = 22910125;
      ykkeychain = 16961659;
      yklappy = 22373686;
      ykmbp = 22373683;
    };
    # Auto-lock screen when YubiKey is removed (useful for laptops)
    # Only works on Linux with systemd (not macOS)
    autoScreenLock = lib.mkDefault false; # Enable per-machine as needed
  };
}
