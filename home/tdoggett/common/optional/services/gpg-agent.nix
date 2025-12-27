{ pkgs, lib, ... }:
{
  services.gpg-agent = {
    maxCacheTtl = 34560000;
    defaultCacheTtl = 34560000;
    pinentry.package = lib.mkForce pkgs.pinentry-gtk2;
  };
}
