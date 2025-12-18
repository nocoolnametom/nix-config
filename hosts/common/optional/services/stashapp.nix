{ ... }:
{
  services.stashapp = {
    enable = true;
  };

  # Ensure the stashapp user is in the shared media group
  users.groups.media = { };
  users.users.stashapp.extraGroups = [ "media" ];

  # Set umask so stashapp creates group-writable files
  systemd.services.stashapp.serviceConfig.UMask = "0002";
}
