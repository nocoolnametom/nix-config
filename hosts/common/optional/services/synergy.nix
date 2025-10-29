{
  pkgs,
  lib,
  config,
  configVars,
  ...
}:
with lib;

let
  cfg = config.services.mysynergy;
in
{
  options.services.mysynergy = with types; {
    enable = mkOption {
      type = bool;
      default = true;
    };
    localMachineName = mkOption {
      type = str;
      default = config.networking.hostName;
    };
    machineToLeft = mkOption {
      type = str;
      default = configVars.networking.work.macbookpro.name;
    };
    settings = mkOption {
      type = str;
      default = "${pkgs.writeText "synergy.conf" ''
        section: screens
                ${cfg.localMachineName}:
                        halfDuplexCapsLock = false
                        halfDuplexNumLock = false
                        halfDuplexScrollLock = false
                        xtestIsXineramaUnaware = false
                        switchCorners = none 
                        switchCornerSize = 0
                ${cfg.machineToLeft}:
                        ctrl = super
                        super = ctrl
                        halfDuplexCapsLock = false
                        halfDuplexNumLock = false
                        halfDuplexScrollLock = false
                        xtestIsXineramaUnaware = false
                        switchCorners = none 
                        switchCornerSize = 0
        end

        section: aliases
        end

        section: links
                ${cfg.localMachineName}:
                        left = ${cfg.machineToLeft}
                ${cfg.machineToLeft}:
                        right = ${cfg.localMachineName}
        end

        section: options
                relativeMouseMoves = false
                win32KeepForeground = false
                disableLockToScreen = false
                clipboardSharing = true
                clipboardSharingSize = 3072
                switchCorners = none +top-left +bottom-left +bottom-right 
                switchCornerSize = 0
        end
      ''}";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets."synergy/tls/${configVars.networking.work.macbookpro.name}" = { };

    services.synergy.client.enable = mkDefault true;
    services.synergy.client.serverAddress = mkDefault configVars.networking.work.macbookpro.ip;
    services.synergy.client.tls.enable = mkDefault true;
    services.synergy.client.tls.cert =
      mkDefault
        config.sops.secrets."synergy/tls/${configVars.networking.work.macbookpro.name}".path;
  };
}
