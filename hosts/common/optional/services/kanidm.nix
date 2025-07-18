{ pkgs, lib, configVars, ... }:
{
  # Kanidm SSO Provider
  services.kanidm.enableServer = true;
  services.kanidm.package = pkgs.kanidm;
  services.kanidm.serverSettings = {
    bindaddress = "127.0.0.1:8443";
    origin = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}";
    domain = configVars.homeDomain;
    log_level = "info";
    tls_chain = "/var/lib/acme/${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/fullchain.pem";
    tls_key = "/var/lib/acme/${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/key.pem";
  };
} 