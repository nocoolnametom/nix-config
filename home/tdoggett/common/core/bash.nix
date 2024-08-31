{ lib, ... }:
{
  programs.bash = {
    enable = lib.mkDefault true;
    enableCompletion = lib.mkDefault true;
  };
}
