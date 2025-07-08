{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let

  stashappPkg = cfg.package;

  cfg = config.services.stashapp;
  opt = options.services.stashapp;

in
{
  options.services.stashapp = {
    enable = lib.mkEnableOption "Enable Stashapp service";

    user = lib.mkOption {
      type = lib.types.str;
      default = "stashapp";
      description = "User account under which Stashapp runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "stashapp";
      description = "Group under which Stashapp runs.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "The ip address for the host that stash is listening to.";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 9999;
      description = "The port that stash serves to.";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/stashapp";
      description = "Path where to store data files.";
    };

    ffmpeg-package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ffmpeg;
      defaultText = lib.literalExpression "pkgs.ffmpeg";
      description = "FFMpeg package to use.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.stashapp; # From local packages!
      defaultText = lib.literalExpression "pkgs.stashapp";
      description = "Stashapp package to use.";
    };

    tools-package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.stashapp-tools; # From local packages!
      defaultText = lib.literalExpression "pkgs.stashapp-tools";
      description = "Stashapp python tools package to use.";
    };

    vr-helper = {
      enable = lib.mkEnableOption "Enable Stashapp service";

      stash-host = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1";
        description = "Accessible host running stash - used by clients, not by the vr helper.";
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = 9666;
        description = "The port that stash-vr serves to.";
      };

      apiEnvironmentVariableFile = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Optional file containing stash API key behind a key of STASH_API_KEY.";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.stash-vr; # From local packages!
        defaultText = lib.literalExpression "pkgs.stash-vr";
        description = "Stash-vr package to use.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      stashPackages = with pkgs; [
        bashInteractive
        openssl
        sqlite
        chromium
        yt-dlp
        cfg.tools-package
        cfg.ffmpeg-package
      ];
    in
    {
      environment.systemPackages = stashPackages;

      systemd.services.stashapp = {
        enable = true;
        description = "Stashapp daemon";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        restartIfChanged = true; # Whether to restart on a nixos-rebuild
        environment = {
          STASH_HOST = cfg.host;
          STASH_PORT = toString cfg.port;
        };

        path = stashPackages;

        preStart = ''
          mkdir -p ~/.stash && chmod 777 ~/.stash;
          rm -f ~/.stash/ffmpeg && ln -s ${cfg.ffmpeg-package}/bin/ffmpeg ~/.stash/ffmpeg;
          rm -f ~/.stash/ffprobe && ln -s ${cfg.ffmpeg-package}/bin/ffprobe ~/.stash/ffprobe;
          chmod 755 ~
        '';

        script = "${cfg.package}/bin/stashapp";
        scriptArgs = "--nobrowser";

        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          # User and group
          User = cfg.user;
          Group = cfg.group;
        };
      };

      systemd.services.stash-vr = {
        enable = cfg.vr-helper.enable;
        description = "Stash-vr daemon";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        restartIfChanged = true; # Whether to restart on a nixos-rebuild
        environment = {
          STASH_GRAPHQL_URL = "${cfg.vr-helper.stash-host}/graphql";
        };

        script = "${cfg.vr-helper.package}/bin/stash-vr";
        scriptArgs = "--LISTEN_ADDRESS:${toString cfg.vr-helper.port}";

        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          # User and group
          User = cfg.user;
          Group = cfg.group;
          EnvironmentFile = [
            cfg.vr-helper.apiEnvironmentVariableFile
          ];
        };
      };

      users.users = lib.mkMerge [
        (lib.mkIf (cfg.user == "stashapp") {
          stashapp = {
            isSystemUser = true;
            group = cfg.group;
            extraGroups = [ "video" ];
            home = cfg.dataDir;
            createHome = true;
          };
        })
        (lib.attrsets.setAttrByPath
          [
            cfg.user
            "packages"
          ]
          [
            cfg.package
            cfg.tools-package
          ]
        )
      ];

      users.groups = lib.optionalAttrs (cfg.group == "stashapp") { stashapp = { }; };
    }
  );
}
