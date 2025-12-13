{
  config,
  configVars,
  pkgs,
  ...
}:
let
  apikey = "pk1_1135d3a13249bb1894ce313f983179f0ec5f35c45292c2af0d96fd0d317a98b4";
in
{
  sops.secrets."ddclient-password" = { };
  services.ddclient = {
    package = pkgs.unstable.ddclient;
    enable = true;
    ssl = true;
    protocol = "porkbun";
    username = apikey;
    passwordFile = "${config.sops.secrets."ddclient-password".path}";
    domains = [
      "home.${configVars.domain}"
      "${configVars.healthDomain}"
      "${configVars.networking.subdomains.punch}.${configVars.domain}"
      "${configVars.networking.subdomains.punch}.${configVars.homeDomain}"
    ];
    # This is because the porkbun protocol requires they keys "apikey" and "secretapikey" instead of "username" and "password"
    extraConfig = ''
      apikey=${apikey}
      secretapikey=@password_placeholder@
    '';
  };
}
