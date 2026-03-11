{ pkgs, lib, ... }:
{
  # Plymouth boot animation — shows a graphical splash instead of kernel messages.
  # Uses the classic Nix lambda snowflake logo on a default plymouth theme.
  # Pair with hosts/common/optional/boot/silent.nix to suppress kernel text output.
  boot.plymouth.enable = lib.mkDefault true;
  boot.plymouth.logo = lib.mkDefault "${pkgs.nixos-icons}/share/icons/hicolor/48x48/apps/nix-snowflake-white.png";
}
