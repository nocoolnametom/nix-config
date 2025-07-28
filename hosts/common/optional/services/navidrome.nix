{ lib, configVars, ... }:
{
  # Navidrome Music Server
  services.navidrome.enable = lib.mkDefault true;
  services.navidrome.settings.Address = lib.mkDefault "0.0.0.0";
  services.navidrome.settings.Port = lib.mkDefault 4533;
  services.navidrome.settings.BaseUrl = lib.mkDefault "/music";
  services.navidrome.settings.MusicFolder = lib.mkDefault "/mnt/Backup/Takeout/${configVars.handle}/Google_Play_Music";
  services.navidrome.settings.DataFolder = lib.mkDefault "/var/lib/navidrome";
}
