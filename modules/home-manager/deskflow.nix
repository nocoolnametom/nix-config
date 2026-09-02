{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.deskflow;
in
{

  options.services.deskflow.client = {
    enable = lib.mkEnableOption "Deskflow Client";

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "-f" ];
      defaultText = lib.literalExpression ''[ "-f" ]'';
      description = ''
        Additional flags to pass to {command}`deskflow-core client`.
        See {command}`deskflow-core --help`.
      '';
    };
  };

  config = lib.mkIf cfg.client.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "services.deskflow" pkgs lib.platforms.linux)
    ];

    systemd.user.services.deskflow = {
      Unit = {
        Description = "Deskflow Client daemon";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service.ExecStart =
        with cfg.client;
        toString (
          [ "${pkgs.deskflow}/bin/deskflow-core client" ]
          ++ extraFlags
        );
    };
  };
}
