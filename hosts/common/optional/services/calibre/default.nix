{ pkgs, config, ... }:
let
  calibreLibrary = "/media/g_drive/Calibre";
  calibre-update = pkgs.callPackage ./calibre-update-pkg.nix { };
in
{
  # Calibre Server
  services.calibre-server.enable = true;
  services.calibre-server.libraries = [ "${calibreLibrary}" ];
  systemd.services.calibre-server.serviceConfig.ExecStart =
    if config.services.calibre-server.enable then
      (pkgs.lib.mkForce "${pkgs.lib.concatStringsSep " " (
        [
          "${pkgs.calibre}/bin/calibre-server"
          "--enable-auth"
          "--enable-local-write"
        ]
        ++ config.services.calibre-server.libraries
      )}")
    else
      null;
  systemd.services.calibre-server-dropbox-sync =
    if config.services.calibre-server.enable then
      {
        script = "${calibre-update}/bin/calibre-update ${config.users.users.maestral.home}/Dropbox/Books ${calibreLibrary}";
        serviceConfig = {
          Type = "oneshot";
          User = "${config.services.calibre-server.user}";
        };
      }
    else
      { };
  systemd.timers.calibre-server-dropbox-sync =
    if config.services.calibre-server.enable then
      {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "4h";
          OnUnitActiveSec = "4h";
          Unit = "calibre-server-dropbox-sync.service";
        };
      }
    else
      { };

  services.calibre-web.enable = true;
  services.calibre-web.listen.ip = "0.0.0.0";
  services.calibre-web.options.calibreLibrary = "${calibreLibrary}";
}
