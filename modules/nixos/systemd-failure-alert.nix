{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.systemd-failure-alert;
  essentialServiceSources = [
    {
      system = "nixos-upgrade";
      control = config.system.autoUpgrade.enable;
    }
    {
      system = "nix-optimise";
      control = config.nix.optimise.automatic;
    }
    {
      system = "nix-gc";
      control = config.nix.gc.automatic;
    }
  ];
  essentialServices = builtins.map (source: source.system) (
    builtins.filter (source: source.control) essentialServiceSources
  );
  systemdServices = essentialServices ++ cfg.additional-services;
in
{
  options.services.systemd-failure-alert = {
    enable = lib.mkEnableOption "Enable systemd failure alert service";

    email = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable email notifications (requires sendmail/mailserver)";
      };
      address = lib.mkOption {
        type = lib.types.str;
        default = "root@localhost";
        description = "E-mail address to send alerts to";
      };
    };

    additional-services = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "nixos-upgrade"
        "nix-optimise"
      ];
      description = ''
        List of systemd services to monitor for failure
        Note that an empty service WILL be created if it is not already defined!
      '';
    };

    pushover = {
      enable = lib.mkEnableOption "Enable Pushover notifications";
      userKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to file containing Pushover user key";
      };
      apiTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to file containing Pushover API token";
      };
      priority = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Pushover priority (-2 to 2, where 1 = high priority, 2 = emergency)";
      };
    };
  };

  config = lib.mkIf (cfg.enable && (builtins.lessThan 0 (builtins.length systemdServices))) {
    # Warn if neither notification method is enabled
    warnings = lib.optional (
      !cfg.email.enable && !cfg.pushover.enable
    ) "systemd-failure-alert is enabled but neither email nor pushover notifications are enabled";

    # Define systemd template units for reporting service failures
    systemd.services = (
      # Email notification service (only if enabled)
      lib.optionalAttrs (cfg.email.enable) {
        "notify-email@" = {
          environment.EMAIL_ADDRESS = lib.strings.replaceStrings [ "%" ] [ "%%" ] cfg.email.address;
          environment.SERVICE_ID = "%i";
          path = with pkgs; [
            coreutils
            systemd
            mailutils
          ];
          script = ''
            {
               echo "Date: $(date -R)"
               echo "From: root (systemd notify-email)"
               echo "To: $EMAIL_ADDRESS"
               echo "Subject: [$(hostname)] service $SERVICE_ID failed"
               echo "Auto-Submitted: auto-generated"
               echo
               systemctl status "$SERVICE_ID" ||:
            } | sendmail "$EMAIL_ADDRESS"
          '';
        };
      }
      # Pushover notification service (only if enabled)
      // lib.optionalAttrs (cfg.pushover.enable) {
        "notify-pushover@" = {
          environment.SERVICE_ID = "%i";
          path = with pkgs; [
            curl
            systemd
            coreutils
          ];
          script = ''
            # Read API credentials from files
            PUSHOVER_USER_KEY=$(cat ${cfg.pushover.userKeyFile})
            PUSHOVER_API_TOKEN=$(cat ${cfg.pushover.apiTokenFile})

            # Get hostname and service status
            HOSTNAME=$(hostname)
            SERVICE_STATUS=$(systemctl status "$SERVICE_ID" 2>&1 | head -n 20)

            # Send Pushover notification
            ${pkgs.curl}/bin/curl -s \
              --form-string "token=$PUSHOVER_API_TOKEN" \
              --form-string "user=$PUSHOVER_USER_KEY" \
              --form-string "title=[$HOSTNAME] Service Failure" \
              --form-string "message=Service $SERVICE_ID has failed on $HOSTNAME" \
              --form-string "priority=${toString cfg.pushover.priority}" \
              https://api.pushover.net/1/messages.json
          '';
        };
      }
      # Add onFailure handlers to monitored services
      // (lib.attrsets.genAttrs systemdServices (
        name:
        let
          # Build list of notifiers based on what's enabled
          notifiers =
            lib.optional cfg.email.enable "notify-email@%i.service"
            ++ lib.optional cfg.pushover.enable "notify-pushover@%i.service";
        in
        {
          onFailure = lib.mkBefore notifiers;
        }
      ))
    );
  };
}
