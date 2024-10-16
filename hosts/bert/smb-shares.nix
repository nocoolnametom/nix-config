{ ... }:
{
  # Samba Server
  services.samba.enable = true;
  # Remember that you have to set up a samba user IN SAMBA for non-guest shares!
  # Samba users are NOT the same as system users!
  services.samba.settings = {
    global = {
      "workgroup" = "WORKGROUP";
      "server string" = "bert";
      "netbios name" = "bert";
      "security" = "user";
      "guest account" = "nobody";
      "map to guest" = "bad user";
      "load printers" = "no";
      "printcap name" = "/dev/null";
    };
    movies = {
      comment = "Movies";
      path = "/media/g_drive/Movies/";
      "read only" = true;
      "guest ok" = true;
      writable = false;
      browseable = true;
    };
    tv_shows = {
      comment = "TV Shows";
      path = "/media/g_drive/TV_Shows/";
      "read only" = true;
      "guest ok" = true;
      writable = false;
      browseable = true;
    };
    g_drive = {
      public = false;
      comment = "Drive";
      path = "/media/g_drive/";
      "read only" = false;
      "guest ok" = false;
      writable = true;
      browseable = true;
      "force user" = "tdoggett";
      "force group" = "tdoggett";
    };
    backup = {
      public = false;
      comment = "Backup";
      path = "/mnt/Backup/share/";
      "read only" = false;
      "guest ok" = false;
      writable = true;
      browseable = true;
      "force user" = "tdoggett";
      "force group" = "tdoggett";
    };
    borgbackup = {
      public = false;
      comment = "BorgBackup";
      path = "/mnt/Backup/gdrive-borgbackup/";
      "read only" = false;
      "guest ok" = false;
      writable = true;
      browseable = true;
      "force user" = "tdoggett";
      "force group" = "users";
    };
  };
}
