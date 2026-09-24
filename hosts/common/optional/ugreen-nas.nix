# This file has been superseded by the proper NixOS module at:
#
#   modules/nixos/ugreen-nas.nix
#
# That module is automatically imported into all NixOS configurations via
# hosts/common/core/default.nix (builtins.attrValues outputs.nixosModules).
#
# Configure UGREEN NAS hardware directly in your host's default.nix:
#
#   hardware.ugreenNas = {
#     enable = true;
#     leds.enable = true;
#     leds.diskiomon.enable = true;
#     leds.netdevmon = { enable = true; interface = "enp2s0"; };
#   };
#
# This stub exists only so that any remaining imports of this path do not
# cause a file-not-found error while the migration is being completed.
{ ... }: { }
