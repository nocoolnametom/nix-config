{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.yknotify;

  launcher = pkgs.writeShellApplication {
    name = "yknotify-launcher";
    runtimeInputs = [
      pkgs.yknotify
      pkgs.jq
      pkgs.terminal-notifier
    ];
    text = ''
      LAST_NTFY=0
      yknotify | while IFS= read -r line; do
        NOW=$(date +%s)
        if (( NOW <= LAST_NTFY + ${toString cfg.dedupSeconds} )); then
          continue
        fi
        LAST_NTFY=$NOW
        message=$(jq -r '.type' <<< "$line")
        terminal-notifier \
          -title "yknotify" \
          -message "YubiKey touch: $message" \
          -sound "${cfg.sound}"
      done
    '';
  };
in
{
  options.services.yknotify = {
    enable = lib.mkEnableOption "yknotify YubiKey touch notifier (macOS)";

    sound = lib.mkOption {
      type = lib.types.str;
      default = "Submarine";
      description = "macOS system sound to play with the notification. See /System/Library/Sounds/.";
    };

    dedupSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Suppress duplicate notifications within this many seconds.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.yknotify ];

    launchd.user.agents.yknotify = {
      serviceConfig = {
        Label = "com.user.yknotify";
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/yknotify.out";
        StandardErrorPath = "/tmp/yknotify.err";
        ProgramArguments = [
          "${launcher}/bin/yknotify-launcher"
        ];
      };
    };
  };
}
