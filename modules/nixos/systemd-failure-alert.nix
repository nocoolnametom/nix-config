{
  lib,
  config,
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
    emailAddress = lib.mkOption {
      type = lib.types.str;
      default = "root@localhost";
      description = "E-mail address to send alerts to";
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
  };

  config = lib.mkIf (cfg.enable && (builtins.lessThan 0 (builtins.length systemdServices))) {
    # Define systemd template unit for reporting service failures via e-mail
    systemd.services = (
      {
        "notify-email@" = {
          environment.EMAIL_ADDRESS = lib.strings.replaceStrings [ "%" ] [ "%%" ] cfg.emailAddress;
          environment.SERVICE_ID = "%i";
          path = [
            "/run/wrappers"
            "/run/current-system/sw"
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

        # Merge `onFailure` attribute for all monitored services
      }
      // (lib.attrsets.genAttrs systemdServices (name: {
        onFailure = lib.mkBefore [ "notify-email@%i.service" ];
      }))
    );
  };
}
