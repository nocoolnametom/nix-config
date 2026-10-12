{
  lib,
  pkgs,
  config,
  configVars,
  ...
}:
let
  smtpSecretNames = [
    "host"
    "port"
    "username"
    "password"
    "sendingDomain"
    "ssl"
  ];
  smtpPlaceholder = name: config.sops.placeholder."homelab/smtp/${name}";

  # Failure alerts go straight to the homelab SMTP provider (the same account karakeep, paperless
  # and mealie use) with msmtp, instead of through the local Postfix -> Gmail relay. Postfix
  # stays below for everything else on the box that calls sendmail (e.g. WordPress).
  alertSendCommand = pkgs.writeShellScript "systemd-failure-alert-msmtp" ''
    # homelab/smtp/ssl decides between implicit TLS (e.g. port 465) and STARTTLS (e.g. port 587)
    useStartTls=on
    case "$(${pkgs.coreutils}/bin/tr -d '[:space:]' < ${
      config.sops.secrets."homelab/smtp/ssl".path
    } | ${pkgs.coreutils}/bin/tr '[:upper:]' '[:lower:]')" in
      true | 1 | yes | on) useStartTls=off ;;
    esac
    exec ${pkgs.msmtp}/bin/msmtp \
      --file=${config.sops.templates."systemd-failure-alert-msmtprc".path} \
      --tls-starttls="$useStartTls" \
      -- "$@"
  '';
in
{
  services.systemd-failure-alert.enable = lib.mkDefault true;
  services.systemd-failure-alert.email.enable = lib.mkDefault true;
  services.systemd-failure-alert.email.address = lib.mkDefault configVars.email.alerts;
  services.systemd-failure-alert.email.sendCommand = "${alertSendCommand}";

  sops.secrets = lib.genAttrs (map (name: "homelab/smtp/${name}") smtpSecretNames) (_: { }) // {
    "postfix-sasl-passwd".owner = config.services.postfix.user;
  };
  # Read by the notify-email@ units, which run as root
  sops.templates."systemd-failure-alert-msmtprc".content = ''
    account default
    host ${smtpPlaceholder "host"}
    port ${smtpPlaceholder "port"}
    auth on
    user ${smtpPlaceholder "username"}
    password ${smtpPlaceholder "password"}
    tls on
    tls_trust_file /etc/ssl/certs/ca-certificates.crt
    from no-reply+alerts@${smtpPlaceholder "sendingDomain"}
    # Replace the script's placeholder "From: root" header with the real sender address
    set_from_header on
    # Give up on one address quickly so a dead IPv6 route falls through to IPv4
    timeout 15
    syslog LOG_MAIL
  '';

  services.postfix.enable = true;
  services.postfix.settings.main.relayhost = [
    "[smtp.gmail.com]:587"
  ];
  # Try the relay over IPv4 first. On bombadil (2026-10-12) outbound IPv6 timed out even though
  # an IPv6 default route existed, so most relay attempts died on smtp.gmail.com's AAAA records.
  services.postfix.settings.main.smtp_address_preference = "ipv4";
  services.postfix.settings.main.smtp_use_tls = "yes";
  services.postfix.settings.main.smtp_sasl_auth_enable = "yes";
  services.postfix.settings.main.smtp_sasl_security_options = "";
  services.postfix.settings.main.smtp_sasl_password_maps = "texthash:${
    config.sops.secrets."postfix-sasl-passwd".path
  }";
}
