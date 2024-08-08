# A nice UI for various torrent clients
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.flood;
in
{
  options.services.flood = with lib; {
    enable = mkEnableOption "Flood UI";

    port = mkOption {
      type = types.port;
      default = 9092;
      example = 3000;
      description = "Internal port for Flood UI";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/flood";
      example = "floodUI";
      description = "Directory for storing Flood's files";
    };

    user = mkOption {
      type = types.str;
      default = "flood";
      description = lib.mdDoc ''
        User account under which flood runs.
      '';
    };

    group = mkOption {
      type = types.str;
      default = "flood";
      description = lib.mdDoc ''
        Group under which flood runs.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.flood = {
      description = "Flood torrent UI";
      after = [
        "network.target"
        "deluged.service"
      ];
      requires = [ "deluged.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.flood ];

      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.flood}/bin/flood"
          "--host 0.0.0.0"
          "--port ${builtins.toString cfg.port}"
          "--rundir ${cfg.dataDir}"
        ];
        StateDirectory = cfg.dataDir;
        ReadWritePaths = "";
        User = cfg.user;
        Group = cfg.group;
      };
    };

    users.users = lib.mkIf (cfg.user == "flood") {
      flood = {
        group = cfg.group;
        uid = 400;
        home = cfg.dataDir;
        description = "Flood UI user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "flood") {
      flood = {
        gid = 400;
      };
    };

  };
}
