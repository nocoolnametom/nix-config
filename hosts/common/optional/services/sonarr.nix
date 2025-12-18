{
  # Sonarr TV NZB Server
  services.sonarr.enable = true;

  # Ensure the sonarr user is in the shared media group
  users.groups.media = { };
  users.users.sonarr.extraGroups = [ "media" ];

  # Set umask so sonarr creates group-writable files when moving/renaming
  systemd.services.sonarr.serviceConfig.UMask = "0002";
}
