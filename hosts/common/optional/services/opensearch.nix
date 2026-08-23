{ lib, pkgs, ... }:
{
  services.opensearch.enable = lib.mkDefault true;
  services.opensearch.package = lib.mkDefault pkgs.opensearch;
  # Need to figure out how to enable xpack security through NixOS
  # services.opensearch.extraConf = ''
  #   xpack.security.enabled: true
  #   xpack.security.transport.ssl.enabled: true
  # '';
}
