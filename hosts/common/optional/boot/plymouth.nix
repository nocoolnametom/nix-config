{ pkgs, ... }:
{
  # Plymouth Boot Animation
  boot.plymouth.enable = true;
  boot.plymouth.logo = "${pkgs.nixos-icons}/share/icons/hicolor/48x48/apps/nix-snowflake-white.png";
}
