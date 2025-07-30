{ ... }:
{
  services.stashapp = {
    enable = true;
  };

  # Ensure the stashapp user is in the shared media group
  users.groups.media = { };
  users.users.stashapp.extraGroups = [ "media" ];
}
