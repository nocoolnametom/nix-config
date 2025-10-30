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
  };

  config = mkIf cfg.enable {
    # sops.secrets."synergy/tls/${config.networking.hostName}" = {
    #   mode = "0600";
    #   owner = configVars.username;
    # };

    services.synergy.client.enable = mkDefault true;
    services.synergy.client.serverAddress = mkDefault configVars.networking.work.macbookpro.ip;
    # services.synergy.client.tls.enable = mkDefault true;
    # services.synergy.client.tls.cert =
    #   mkDefault
    #     config.sops.secrets."synergy/tls/${config.networking.hostName}".path;
  };
}
