{ pkgs, lib, configVars, ... }:
{
  yubikey = {
    enable = lib.mkDefault true;
    identifiers = configVars.yubikey.identifiers;
    # Auto-lock screen when YubiKey is removed (useful for laptops)
    # Only works on Linux with systemd (not macOS)
    autoScreenLock = lib.mkDefault false; # Enable per-machine as needed
  };
}
