{ lib, ... }:
{
  services.postfix.enable = lib.mkDefault true;
}
