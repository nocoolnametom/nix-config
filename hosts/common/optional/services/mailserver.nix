{
  lib,
  config,
  configVars,
  ...
}:
{
  sops.secrets."postfix-sasl-passwd".owner = config.services.postfix.user;
  services.postfix.enable = lib.mkDefault true;
  services.postfix.relayHost = "smtp.gmail.com";
  services.postfix.relayPort = 587;
  services.postfix.config.smtp_use_tls = "yes";
  services.postfix.config.smtp_sasl_auth_enable = "yes";
  services.postfix.config.smtp_sasl_security_options = "";
  services.postfix.config.smtp_sasl_password_maps = "texthash:${
    config.sops.secrets."postfix-sasl-passwd".path
  }";

  # Define systemd template unit for reporting service failures via e-mail
  systemd.services =
    {
      "notify-email@" = {
        environment.EMAIL_ADDRESS = lib.strings.replaceStrings [ "%" ] [ "%%" ] configVars.email.alerts;
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
    // (lib.attrsets.genAttrs
      [
        "nixos-upgrade"
        "nixos-store-optimize"
      ]
      (name: {
        onFailure = lib.mkBefore [ "notify-email@%i.service" ];
      })
    );
}
