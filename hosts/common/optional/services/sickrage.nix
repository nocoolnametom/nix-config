{ pkgs, ... }:
{
  # Note that I've set the url prefix in the sickgear config to be "/tv" to
  # aid in reverse proxying so you'll have to hit this at
  # http://<ip_address>:<port>/tv/
  services.sickbeard.enable = true;
  services.sickbeard.package = pkgs.sickgear;
  services.sickbeard.dataDir = "/var/lib/sickgear";
  services.sickbeard.port = 8081;
  systemd.services.sickbeard.path = with pkgs; [
    unrar
    unzip
    gzip
    xz
    bzip2
    gnutar
    p7zip
    py7zr
    (pkgs.python3.withPackages (
      p: with p; [
        requests
        pandas
        configparser
        cheetah3
        lxml
        py7zr
      ]
    ))
    ffmpeg
  ];

  # Ensure the sickbeard user is in the shared media group
  users.groups.media = { };
  users.users.sickbeard.extraGroups = [ "media" ];
}
