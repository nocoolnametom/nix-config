{ inputs, pkgs, lib, ... }:
{
  imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

  services.flatpak.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  # Fallback for machines with no desktop environment; DEs override this via their own modules.
  xdg.portal.config = lib.mkDefault { common.default = "*"; };
}
