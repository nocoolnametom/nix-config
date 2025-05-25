#
# greeter -> tuigreet https://github.com/apognu/tuigreet?tab=readme-ov-file
# display manager -> greetd https://man.sr.ht/~kennylevinsen/greetd/
#

{
  config,
  configVars,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.autoLogin;
in
{
  # Declare custom options for conditionally enabling auto login
  options.autoLogin = {
    enable = lib.mkEnableOption "Enable automatic login";

    username = lib.mkOption {
      type = lib.types.str;
      default = configVars.username;
      description = "User to automatically login";
    };
  };

  config = {
    #    environment.systemPackages = with pkgs; [ greetd.tuigreet ];
    services.greetd = {
      enable = lib.mkDefault true;

      restart = lib.mkDefault true;
      settings = {
        default_session = {
          command = lib.mkDefault "${pkgs.greetd.tuigreet}/bin/tuigreet --asterisks --time --time-format '%I:%M %p | %a • %h | %F' --cmd ${pkgs.uwsm}/bin/uwsm start hyprland.desktop";
          user = lib.mkForce "${cfg.username}";
        };

        initial_session = lib.mkIf cfg.enable {
          command = lib.mkDefault "${pkgs.uwsm}/bin/uwsm start ${config.programs.hyprland.package}/bin/Hyprland";
          user = lib.mkDefault "${cfg.username}";
        };
      };
    };
  };
}
