# You'll have to sudo in as `maestral` to set up the initial connection to Dropbox
# This is a system-level service meant to sync Dropbox files for the entire system
# For a user-level service I haven't written one yet
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let

  maestralPkg = cfg.package;
  cfg = config.services.maestral;

in
{
  options.services.maestral = {
    enable = lib.mkEnableOption "Enable Maestral service";

    user = lib.mkOption {
      type = lib.types.str;
      default = "maestral";
      description = "User account under which Maestral runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "maestral";
      description = "Group under which Maestral runs.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/maestral";
      description = "Path where to store data files.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.maestral;
      defaultText = lib.literalExpression "pkgs.maestral";
      description = "Maestral package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services.maestral = {
      enable = true;
      description = "Maestral daemon";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      restartIfChanged = true; # Whether to restart on a nixos-rebuild

      serviceConfig = {
        Type = "notify";
        NotifyAccess = "exec";
        ExecStart = "${cfg.package}/bin/maestral start -f";
        ExecStop = "${cfg.package}/bin/maestral stop";
        Restart = "on-failure";
        Watchdog = "30s";
        # User and group
        User = cfg.user;
        Group = cfg.group;
      };
    };

    users.users = lib.mkMerge [
      (lib.mkIf (cfg.user == "maestral") {
        maestral = {
          isSystemUser = true;
          group = cfg.group;
          home = cfg.dataDir;
          createHome = true;
          homeMode = "755";
        };
      })
      (lib.attrsets.setAttrByPath [
        cfg.user
        "packages"
      ] [ cfg.package ])
    ];

    users.groups = lib.optionalAttrs (cfg.group == "maestral") { maestral = { }; };
  };
}
