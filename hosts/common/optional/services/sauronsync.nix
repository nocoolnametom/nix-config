{ configVars, config, ... }:
{
  services.sauronsync = {
    enable = true;
    ip = "192.168.0.168";
    localUser = configVars.username;
    remoteUser = configVars.username;
    sshPrivateKey = config.sops.secrets."root-github-key".path;
    localDestDir = "/media/g_drive/nzbget/dest/software/finished";
    remoteSourceDir = "/home/tdoggett/WindowsDocuments/films_to_double/finished";
    remoteFinishedDir = "/home/tdoggett/WindowsDocuments/films_to_double/transferred";
  };
}
