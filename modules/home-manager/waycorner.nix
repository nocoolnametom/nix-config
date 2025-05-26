# See https://github.com/berbiche/dotfiles/blob/4048a1746ccfbf7b96fe734596981d2a1d857930/modules/home-manager/waycorner.nix#L9
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.waycorner;
  settingsFormat = pkgs.formats.toml { };
  settingsFile = settingsFormat.generate "waycorner.toml" cfg.settings;
in
{
  options.services.waycorner = {
    enable = mkEnableOption "a tool to detect when your mouse hits a corner in wayland";

    package = mkOption {
      type = types.package;
      default = pkgs.waycorner;
      defaultText = "pkgs.waycorner";
      description = ''
        Package to use. Binary is expected to be called "waycorner".
      '';
    };

    settings = mkOption {
      inherit (settingsFormat) type;
      default = { };
      description = lib.mdDoc ''
        Configuration included in `config.toml`.

        See https://github.com/AndreasBackx/waycorner#configuration for documentation.
      '';
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      defaultText = literalExpression ''[ ]'';
      description = ''
        Extra arguments to pass to the tool. The arguments are not escaped.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "services.waycorner" pkgs lib.platforms.linux)
    ];

    home.packages = [ cfg.package ];

    # Same license thing for the description here
    systemd.user.services.waycorner = {
      Unit = {
        Description = "Detects when your YubiKey is waiting for a touch";
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/waycorner --config ${settingsFile} ${concatStringsSep " " cfg.extraArgs}";
        Restart = "on-failure";
        RestartSec = "1sec";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
