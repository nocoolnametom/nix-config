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
  };
}
