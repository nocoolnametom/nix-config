{ config, ... }:
{
  # Whisparr (V2) Adult Movie NZB Server
  services.whisparr.enable = true;

  # Keep the config/database on the media pool rather than the system disk
  services.whisparr.dataDir = "/arkenstone/whisparr";

  # Ensure the whisparr user is in the shared media group
  users.groups.media = { };
  users.users.whisparr.extraGroups = [ "media" ];

  # Set umask so whisparr creates group-writable files when moving/renaming
  # (the upstream module leaves UMask unset, so no mkForce needed)
  systemd.services.whisparr.serviceConfig.UMask = "0002";

  # dataDir lives on a separate mount, so don't start before it's available
  systemd.services.whisparr.unitConfig.RequiresMountsFor = [ config.services.whisparr.dataDir ];
}
