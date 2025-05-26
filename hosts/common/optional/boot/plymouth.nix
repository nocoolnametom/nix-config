{ pkgs, lib, ... }:
{
  # Plymouth Boot Animation
  boot.plymouth.enable = lib.mkDefault true;
  boot.plymouth.logo = lib.mkDefault "${pkgs.nixos-icons}/share/icons/hicolor/48x48/apps/nix-snowflake-white.png";
}
