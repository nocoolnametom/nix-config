{ lib, pkgs, ... }:
{
  programs.tmux = lib.mkMerge [
    {
      enable = false;
    }
    (lib.optionalAttrs (pkgs.stdenv.isDarwin) {
      enableMouse = true;
      enableSensible = true;
    })
  ];
}
