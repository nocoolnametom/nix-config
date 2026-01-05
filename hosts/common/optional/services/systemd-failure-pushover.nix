{
  lib,
  config,
  configVars,
  ...
}:
{
  services.systemd-failure-alert.enable = lib.mkDefault true;
  services.systemd-failure-alert.pushover.enable = lib.mkDefault true;
  services.systemd-failure-alert.pushover.priority = lib.mkDefault 1;
  sops.secrets."pushover/user_key" = { };
  sops.secrets."pushover/api_token" = { };
  services.systemd-failure-alert.pushover.userKeyFile = config.sops.secrets."pushover/user_key".path;
  services.systemd-failure-alert.pushover.apiTokenFile = config.sops.secrets."pushover/api_token".path;
}
