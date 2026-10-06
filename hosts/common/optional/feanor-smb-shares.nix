###############################################################################
#
#  feanor SMB mounts for clients (replaces cirdan-smb-shares.nix)
#
#  SMB3 rather than NFS: NFSv4 is a little lighter on CPU for Linux clients,
#  but it would trust clients by IP/uid with no password, and the
#  limited-access `syncthing` share is gated on the datadat Samba login.
#
#  Two logins, as on cirdan:
#    primary   (general shares; files appear 0777 locally, created on feanor
#               as the share's force group `media`)
#    secondary (datadat; the Syncthing tree incl. limited-access folders,
#               visible locally only to the datadat group)
#
#  Automounted with short timeouts so a network split never hangs the client.
#
###############################################################################

{
  config,
  configVars,
  lib,
  ...
}:
let
  mkMount = credential: extraOpts: share: {
    device = "//${configVars.networking.subnets.feanor.ip}/${share}";
    fsType = "cifs";
    options = [
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=60"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
      "credentials=${config.sops.secrets."feanor-smb-${credential}-secrets".path}"
    ]
    ++ extraOpts;
  };

  general = mkMount "primary" [
    "file_mode=0777"
    "dir_mode=0777"
  ];

  limitedReadOnly = mkMount "secondary" [
    "ro"
    "file_mode=0550"
    "dir_mode=0550"
    "uid=${toString config.users.users.datadat.uid}"
    "gid=${toString config.users.groups.datadat.gid}"
  ];
in
{
  sops.secrets."feanor-smb-primary-secrets" = {
    mode = "0400";
    path = "/var/lib/feanor-smb/primary.txt";
  };
  sops.secrets."feanor-smb-secondary-secrets" = {
    mode = "0400";
    path = "/var/lib/feanor-smb/secondary.txt";
  };

  fileSystems."/mnt/feanor/smb/Comics" = general "Comics";
  fileSystems."/mnt/feanor/smb/Immich" = general "Immich";
  fileSystems."/mnt/feanor/smb/Jellyfin" = general "Jellyfin";
  fileSystems."/mnt/feanor/smb/Music" = general "Music";
  fileSystems."/mnt/feanor/smb/NetBackup" = general "NetBackup";
  fileSystems."/mnt/feanor/smb/syncthing" = limitedReadOnly "syncthing";
}
