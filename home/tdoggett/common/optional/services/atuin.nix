{
  lib,
  config,
  configVars,
  ...
}:
let
  atuinSecretPath = "atuin/${configVars.networking.subnets.estel.name}/${configVars.username}";
in
{
  programs.atuin.enable = lib.mkDefault true;
  programs.atuin.daemon.enable = lib.mkDefault true;
  programs.atuin.settings.sync_address = lib.mkDefault "https://${
    configVars.networking.subdomains."atuin-sync"
  }.${configVars.homeDomain}";
  # Sops deploys the raw key to a tmpfs path; atuin reads it from there.
  # The key must be the raw bech32 key (output of `cat ~/.local/share/atuin/key`),
  # NOT the mnemonic words shown during registration.
  sops.secrets."${atuinSecretPath}" = { };
  programs.atuin.settings.key_path = lib.mkDefault config.sops.secrets."${atuinSecretPath}".path;
}
