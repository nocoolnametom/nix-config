{ config, configVars, ... }:
{
  sops.secrets."ddclient-password" = { };
  services.ddclient = {
    enable = true;
    ssl = true;
    protocol = "googledomains";
    username = "jIuresUnUC1pBaK1";
    passwordFile = "${config.sops.secrets."ddclient-password".path}";
    domains = [ "home.${configVars.domain}" ];
  };
}
