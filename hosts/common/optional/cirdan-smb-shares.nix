{
  config,
  configVars,
  lib,
  ...
}:
{
  sops.secrets."cirdan-smb/primary/user" = { };
  sops.secrets."cirdan-smb/primary/password" = { };
  sops.secrets."cirdan-smb/secondary/user" = { };
  sops.secrets."cirdan-smb/secondary/password" = { };
  sops.templates."cirdan-smb-primary-creds" = {
    content = ''
      username=${config.sops.placeholder."cirdan-smb/primary/user"}
      password=${config.sops.placeholder."cirdan-smb/primary/password"}
    '';
    neededForUsers = true;
  };
  sops.templates."cirdan-smb-secondary-creds" = {
    content = ''
      username=${config.sops.placeholder."cirdan-smb/secondary/user"}
      password=${config.sops.placeholder."cirdan-smb/secondary/password"}
    '';
    neededForUsers = true;
  };
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
        "${automount_opts},credentials=${config.sops.templates."cirdan-smb-${ordinal}-creds".path},"
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
}
