{ ... }:
{
  # Note that I've set the url prefix in the sickgear config to be "/tv" to
  # aid in reverse proxying so you'll have to hit this at
  # http://<ip_address>:<port>/tv/
  services.sickbeard.enable = true;
  services.sickbeard.package = pkgs.sickgear;
  services.sickbeard.dataDir = "/var/lib/sickgear";
  services.sickbeard.port = 8081;
}
