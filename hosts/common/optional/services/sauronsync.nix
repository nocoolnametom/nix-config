{ configVars, config, ... }:
{
  services.sauronsync = {
    enable = true;
    ip = configVars.networking.subnets.sauron.ip;
    localUser = configVars.username;
    remoteUser = configVars.username;
    sshPrivateKey = config.sops.secrets."root-github-key".path;
    localDestDir = "/media/g_drive/nzbget/dest/software/finished";
    remoteSourceDir = "/home/${configVars.username}/WindowsDocuments/films_to_double/finished";
    remoteFinishedDir = "/home/${configVars.username}/WindowsDocuments/films_to_double/transferred";
  };
}
