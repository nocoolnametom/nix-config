{ lib, ... }: {
  programs.atuin.enable = lib.mkDefault true;
  programs.atuin.daemon.enable = lib.mkDefault true;
}
