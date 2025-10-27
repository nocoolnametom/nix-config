{ pkgs, lib, config, configVars, ... }: with lib; 

let
  cfg = config.services.mysynergy;
in {
  options.services.mysynergy = with types; {
    enable = mkOption {
      type = bool;
      default = true;
    };
  };

  config = mkIf cfg.enable {
    sops.secrets."synergy/tls/${configVars.networking.work.macbookpro.name}" = {};

    services.synergy.client.enable = mkDefault true;
    services.synergy.client.tls.enable = mkDefault true;
    services.synergy.client.serverAddress = mkDefault configVars.networking.subnets.pangolin11.ip;
    services.synergy.client.tls.cert = mkDefault config.sops.secrets."synergy/tls/${configVars.networking.work.macbookpro.name}".path;
  };
}