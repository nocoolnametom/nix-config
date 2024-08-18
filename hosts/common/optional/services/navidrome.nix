{ ... }:
{
  # Navidrome Music Server
  services.navidrome.enable = true;
  services.navidrome.settings = {
    Address = "0.0.0.0";
    Port = "4533";
    BaseUrl = "/music";
    # MusicFolder = "/mnt/Backup/Takeout/nocoolnametom/Google_Play_Music";
    DataFolder = "/var/lib/navidrome";
  };
}
