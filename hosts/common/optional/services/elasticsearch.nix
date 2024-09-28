{ lib, pkgs, ... }:
{
  services.elasticsearch.enable = lib.mkDefault true;
  services.elasticsearch.package = lib.mkDefault pkgs.elasticsearch7;
  # Need to figure out how to enable xpack security through NixOS
  # services.elasticsearch.extraConf = ''
  #   xpack.security.enabled: true
  #   xpack.security.transport.ssl.enabled: true
  # '';
}
