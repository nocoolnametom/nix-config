# A nice UI for various torrent clients
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.sauronsync;
  sauronEquivalenceMoveScript =
    {
      local,
      remoteSource,
      remoteDest,
    }:
    pkgs.writeShellScriptBin "equivalenceMoveScript.sh" ''
      # Define variables
      local_directory="${local}"
      remote_user="${cfg.remoteUser}"
      remote_host="${cfg.ip}"
      remote_directory="${remoteSource}"
      remote_backup_directory="${remoteDest}"

      # SSH options, including the private key
      ssh_options="-i ${cfg.sshPrivateKey}"

      # Check remote access before proceeding
      if ${pkgs.openssh}/bin/ssh $ssh_options -q $remote_user@$remote_host exit; then
        echo ""
      else
        echo "Error: Remote computer is not accessible."
        exit 1
      fi

      # Check if local directory exists
      if [ ! -d "$local_directory" ]; then
          echo "Local directory does not exist: $local_directory"
          exit 1
      fi

      mkdir -p $local_directory/_unpack

      # Create remote backup directory if not exists
      ${pkgs.openssh}/bin/ssh $ssh_options $remote_user@$remote_host "mkdir -p \"$remote_backup_directory\""

      filelist=$(mktemp)
      unfinished=$(mktemp)
      readyFiles=$(mktemp)

      ${pkgs.rsync}/bin/rsync -naic --out-format="%n%L" -e "${pkgs.openssh}/bin/ssh $ssh_options" "$remote_user@$remote_host:$remote_directory/" "$local_directory/_unpack/" | tail -n +2 > $unfinished
      ls $local_directory/_unpack/ > $filelist
      ${pkgs.gawk}/bin/awk 'NR==FNR{a[$0]=1;next}!a[$0]' $unfinished $filelist > $readyFiles
      while read filename; do
          # Move file from staging
          mv "$local_directory/_unpack/$filename" "$local_directory/"
          
          # Move equal files to the backup directory on the remote machine
          ${pkgs.openssh}/bin/ssh -n $ssh_options $remote_user@$remote_host "mv \"$remote_directory/$filename\" \"$remote_backup_directory/\""
      done < $readyFiles

      rm $filelist $unfinished $readyFiles

      echo "Comparison and move completed successfully."
    '';
in
{
  options.services.sauronsync = with lib; {
    enable = mkEnableOption "Video Sync from Sauron Windows PC";

    ip = mkOption {
      type = types.str;
      default = "192.168.0.168";
      example = "192.168.0.168";
      description = "IP address of the Sauron Windows PC";
    };

    localUser = mkOption {
      type = types.str;
      default = "tdoggett";
      example = "tdoggett";
      description = "User on the local machine";
    };

    remoteUser = mkOption {
      type = types.str;
      default = "tdoggett";
      example = "tdoggett";
      description = "User on the remote machine";
    };

    sshPrivateKey = mkOption {
      type = types.path;
      default = "/home/tdoggett/.ssh/id_rsa";
      example = "/home/tdoggett/.ssh/id_rsa";
      description = "Path to the private key for the SSH connection";
    };

    localDestDir = mkOption {
      type = types.str;
      default = "/media/g_drive/nzbget/dest/software/finished";
      example = "/media/g_drive/nzbget/dest/software/finished";
      description = "Directory for storing the finished files from Sauron";
    };

    remoteSourceDir = mkOption {
      type = types.str;
      default = "/home/tdoggett/WindowsDocuments/films_to_double/finished";
      example = "/home/tdoggett/WindowsDocuments/films_to_double/finished";
      description = "Directory on Sauron where the finished files are stored";
    };

    remoteFinishedDir = mkOption {
      type = types.str;
      default = "/home/tdoggett/WindowsDocuments/films_to_double/transferred";
      example = "/home/tdoggett/WindowsDocuments/films_to_double/transferred";
      description = "Directory on Sauron where the finished files are moved after being copied to the local machine";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.sauron-video-sync =
      let
        script = pkgs.writeShellScriptBin "syncFiles.sh" ''
          mkdir -p ${cfg.localDestDir}/_unpack/
          ${pkgs.rsync}/bin/rsync -avz -e "${pkgs.openssh}/bin/ssh -i ${cfg.sshPrivateKey}" ${cfg.remoteUser}@${cfg.ip}:${cfg.remoteSourceDir}/ ${cfg.localDestDir}/_unpack/
        '';
      in
      {
        serviceConfig.Type = "oneshot";
        script = "${script}/bin/syncFiles.sh";
      };
    systemd.timers.sauron-video-sync = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10m";
        OnUnitActiveSec = "1h";
        Unit = "sauron-video-sync.service";
      };
    };
    systemd.services.sauron-finished-video-move =
      let
        script = sauronEquivalenceMoveScript {
          local = cfg.localDestDir;
          remoteSource = cfg.remoteSourceDir;
          remoteDest = cfg.remoteFinishedDir;
        };
      in
      {
        serviceConfig.Type = "oneshot";
        script = "${script}/bin/equivalenceMoveScript.sh";
      };
    systemd.timers.sauron-finished-video-move = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30m";
        OnUnitActiveSec = "1h";
        Unit = "sauron-finished-video-move.service";
      };
    };
  };
}
