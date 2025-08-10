{
  config,
  configVars,
  lib,
  ...
}:
let
  cirdanSmbGenConfig = ordinal_opts: ordinal: name: {
    device = "//${configVars.networking.subnets.cirdan.ip}/${name}";
    fsType = "cifs";
    options =
      let
        # this line prevents hanging on network split
        mountingOpts = [
          "x-systemd.automount"
          "noauto"
          "x-systemd.idle-timeout=60"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
        ]
        ++ ordinal_opts;
        automount_opts = lib.strings.concatStringsSep "," mountingOpts;
      in
      [
        "${automount_opts},credentials=${config.sops.secrets."cirdan-smb-${ordinal}-secrets".path},"
      ];
  };
  mainConfig = cirdanSmbGenConfig [
    "file_mode=0777"
    "dir_mode=0777"
  ] "primary";
  secondaryConfig = cirdanSmbGenConfig [
    "file_mode=0770"
    "dir_mode=0770"
    "uid=${toString config.users.users.datadat.uid}"
    "gid=${toString config.users.groups.datadat.gid}"
  ] "secondary";
  ROSecondaryConfig = cirdanSmbGenConfig [
    "file_mode=0550"
    "dir_mode=0550"
    "uid=${toString config.users.users.datadat.uid}"
    "gid=${toString config.users.groups.datadat.gid}"
  ] "secondary";
in {
  sops.secrets."cirdan-smb-primary-secrets" = {
    neededForUsers = true;
  };
  sops.secrets."cirdan-smb-secondary-secrets" = {
    neededForUsers = true;
  };

  #Cirdan SMB mounts
  fileSystems."/mnt/cirdan/smb/Comics" = mainConfig "Comics";
  fileSystems."/mnt/cirdan/smb/Jellyfin" = mainConfig "Jellyfin";
  fileSystems."/mnt/cirdan/smb/NetBackup" = mainConfig "NetBackup";
  fileSystems."/mnt/cirdan/smb/data.dat" = secondaryConfig "data.dat";
  fileSystems."/mnt/cirdan/smb/syncthing" = ROSecondaryConfig "syncthing";
}
