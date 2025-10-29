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
    machineToRight = mkOption {
      type = str;
      default = configVars.networking.subnets.pangolin11.name;
    };
    settings = mkOption {
      type = str;
      default = "${pkgs.writeText "synergy.conf" ''
        section: screens
        ''\t${cfg.localMachineName}:
        ''\t''\thalfDuplexCapsLock = false
        ''\t''\thalfDuplexNumLock = false
        ''\t''\thalfDuplexScrollLock = false
        ''\t''\txtestIsXineramaUnaware = false
        ''\t''\tswitchCorners = none
        ''\t''\tswitchCornerSize = 0
        ''\t${cfg.machineToRight}:
        ''\t''\tctrl = super
        ''\t''\tsuper = ctrl
        ''\t''\thalfDuplexCapsLock = false
        ''\t''\thalfDuplexNumLock = false
        ''\t''\thalfDuplexScrollLock = false
        ''\t''\txtestIsXineramaUnaware = false
        ''\t''\tswitchCorners = none
        ''\t''\tswitchCornerSize = 0
        end

        section: aliases
        end

        section: links
        ''\t${cfg.localMachineName}:
        ''\t''\tright = ${cfg.machineToRight}
        ''\t${cfg.machineToRight}:
        ''\t''\tleft = ${cfg.localMachineName}
        end

        section: options
        ''\trelativeMouseMoves = false
        ''\twin32KeepForeground = false
        ''\tdisableLockToScreen = false
        ''\tclipboardSharing = true
        ''\tclipboardSharingSize = 3072
        ''\tswitchCorners = none +top-left +bottom-left +bottom-right
        ''\tswitchCornerSize = 0
        end
      ''}";
    };
  };

  config = mkIf cfg.enable {
    sops.secrets."synergy/tls/${configVars.networking.work.macbookpro.name}" = { };

    services.synergy.server.enable = mkDefault true;
    services.synergy.server.tls.enable = mkDefault true;
    services.synergy.server.tls.cert =
      mkDefault
        config.sops.secrets."synergy/tls/${configVars.networking.work.macbookpro.name}".path;
  };
}
