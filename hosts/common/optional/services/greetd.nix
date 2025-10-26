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
    username = lib.mkOption {
      type = lib.types.str;
      default = configVars.username;
      description = "User to automatically login";
    };
  };

  config = {
    # literally no documentation about this anywhere.
    # https://www.reddit.com/r/NixOS/comments/u0cdpi/tuigreet_with_xmonad_how/
    systemd.services.greetd.serviceConfig.Type = "idle";
    systemd.services.greetd.serviceConfig.StandardInput = "tty";
    systemd.services.greetd.serviceConfig.StandardOutput = "tty";
    # Without this errors will spam on screen
    systemd.services.greetd.serviceConfig.StandardError = "journal";
    # Without these bootlogs will spam on screen
    systemd.services.greetd.serviceConfig.TTYReset = true;
    systemd.services.greetd.serviceConfig.TTYVHangup = true;
    systemd.services.greetd.serviceConfig.TTYVTDisallocate = true;

    services.greetd = {
      enable = lib.mkDefault true;

      restart = lib.mkDefault true;
      settings = {
        default_session = {
          command = lib.mkDefault "${pkgs.tuigreet}/bin/tuigreet --remember --remember-session --time --time-format '%I:%M %p | %a • %h | %F'";
          user = lib.mkForce "${cfg.username}";
        };
      };
    };
  };
}
