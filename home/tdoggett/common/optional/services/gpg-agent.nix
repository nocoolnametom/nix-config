{ pkgs, lib, ... }:
{
  services.gpg-agent = {
    maxCacheTtl = 34560000;
    defaultCacheTtl = 34560000;
    pinentryPackage = lib.mkForce pkgs.pinentry-qt;
  };
}
