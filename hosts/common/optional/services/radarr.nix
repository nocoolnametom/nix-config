{
  # Radarr Movie NZB Server
  services.radarr.enable = true;

  # Ensure the radarr user is in the shared media group
  users.groups.media = { };
  users.users.radarr.extraGroups = [ "media" ];

  # Set umask so radarr creates group-writable files when moving/renaming
  systemd.services.radarr.serviceConfig.UMask = "0002";
}
