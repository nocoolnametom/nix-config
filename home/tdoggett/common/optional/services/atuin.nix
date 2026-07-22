{ lib, configVars, ... }: {
  programs.atuin.enable = lib.mkDefault true;
  programs.atuin.daemon.enable = lib.mkDefault true;
  programs.atuin.settings.sync_address = lib.mkDefault "https://${configVars.networking.subdomains."atuin-sync"}.${configVars.homeDomain}";
}
