{ pkgs, lib, config, ... }:
{
  sops.secrets."netbox-keyfile".owner = "netbox";
  services.netbox.enable = lib.mkDefault true;
  services.netbox.secretKeyFile = config.sops.secrets."netbox-keyfile".path;
  services.netbox.plugins = ps: with ps; [
    ps.netbox-bgp
    ps.netbox-documents
    ps.netbox-reorder-rack
  ];
  services.netbox.settings.PLUGINS = [
    "netbox_bgp"
    "netbox_documents"
    "netbox_reorder_rack"
  ];
}
