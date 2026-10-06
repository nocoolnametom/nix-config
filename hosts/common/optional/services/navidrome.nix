###############################################################################
#
#  Navidrome music server
#
#  Web logins come through Kanidm via the "navidrome" oauth2-proxy instance
#  on estel (oauth2-proxy.nix), which passes the user's short name in
#  X-Forwarded-Preferred-Username. Navidrome trusts that header only from
#  estel's address and creates a user on first login.
#
#  Subsonic API clients (phone apps) authenticate against Navidrome's own
#  user passwords; the proxy lets /rest/ through for them (oauth2-proxy.nix).
#
#  Set services.navidrome.settings.MusicFolder per host.
#
###############################################################################

{
  config,
  lib,
  configVars,
  ...
}:
{
  # The service's sandbox bind-mounts Backup.Path, so it must already exist.
  systemd.tmpfiles.rules = [
    "d ${config.services.navidrome.settings.Backup.Path} 0750 ${config.services.navidrome.user} ${config.services.navidrome.group} -"
  ];

  services.navidrome = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkDefault true; # estel's Caddy/oauth2-proxy connect over the LAN
    settings = {
      Address = lib.mkDefault "0.0.0.0";
      Port = lib.mkDefault configVars.networking.ports.tcp.navidrome;
      BaseUrl = lib.mkDefault "";
      ReverseProxyWhitelist = lib.mkDefault "${configVars.networking.subnets.estel.ip}/32";
      ReverseProxyUserHeader = lib.mkDefault "X-Forwarded-Preferred-Username";
      # Navidrome's own database backups, consistent copies for borg to pick up.
      Backup = {
        Path = lib.mkDefault "/var/lib/navidrome/backups";
        Schedule = lib.mkDefault "0 2 * * *";
        Count = lib.mkDefault 7;
      };
    };
  };
}
