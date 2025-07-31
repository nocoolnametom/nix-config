{ pkgs, lib, config, ... }:
{
  sops.secrets."netbox-keyfile".owner = "netbox";
  services.netbox.enable = lib.mkDefault true;
  services.netbox.secretKeyFile = config.sops.secrets."netbox-keyfile".path;
}
