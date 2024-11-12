{ config, configVars, ... }:
{
  sops.secrets."ddclient-password" = { };
  services.ddclient = {
    enable = true;
    ssl = true;
    protocol = "porkbun";
    username = "pk1_d2c1119ce79c7f8e82ce147518d741671ede87b6c12f88a8b582f14a2746a184";
    passwordFile = "${config.sops.secrets."ddclient-password".path}";
    domains = [ "home.${configVars.domain}" ];
  };
}
