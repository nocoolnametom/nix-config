{ configVars, ... }:
{
  # Samba Server
  services.samba.enable = true;
  # Remember that you have to set up a samba user IN SAMBA for non-guest shares!
  # Samba users are NOT the same as system users!
  # Make a Samba user with the same name as ${configVars.username} to work!
  services.samba.settings = {
    global = {
      "workgroup" = "WORKGROUP";
      "server string" = configVars.networking.subnets.bert.name;
      "netbios name" = configVars.networking.subnets.bert.name;
      "security" = "user";
      "guest account" = "nobody";
      "map to guest" = "bad user";
      "load printers" = "no";
      "printcap name" = "/dev/null";
    };
    backup = {
      public = false;
      comment = "Backup";
      path = "/mnt/Backup/share/";
      "read only" = false;
      "guest ok" = false;
      writable = true;
      browseable = true;
      "force user" = "${configVars.username}";
      "force group" = "${configVars.username}";
    };
    borgbackup = {
      public = false;
      comment = "BorgBackup";
      path = "/mnt/Backup/gdrive-borgbackup/";
      "read only" = false;
      "guest ok" = false;
      writable = true;
      browseable = true;
      "force user" = "${configVars.username}";
      "force group" = "users";
    };
  };
}
