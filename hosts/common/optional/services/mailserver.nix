{
  lib,
  config,
  configVars,
  ...
}:
{
  services.systemd-failure-alert.enable = lib.mkDefault true;
  services.systemd-failure-alert.emailAddress = lib.mkDefault configVars.email.alerts;
  sops.secrets."postfix-sasl-passwd".owner = config.services.postfix.user;
  services.postfix.enable = true;
  services.postfix.relayHost = "smtp.gmail.com";
  services.postfix.relayPort = 587;
  services.postfix.config.smtp_use_tls = "yes";
  services.postfix.config.smtp_sasl_auth_enable = "yes";
  services.postfix.config.smtp_sasl_security_options = "";
  services.postfix.config.smtp_sasl_password_maps = "texthash:${
    config.sops.secrets."postfix-sasl-passwd".path
  }";
}
