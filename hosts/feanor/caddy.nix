###############################################################################
#
#  Feanor - Caddy reverse proxy config
#
#  Two roles:
#    1. Homelab status-page link generation (mirrors hosts/durin/caddy.nix)
#    2. TLS termination for Kanidm SSO (public ingress via bombadil HAProxy →
#       estel Caddy SNI passthrough → here → local Kanidm on port kanidm)
#
#  Public routing path:
#    client → bombadil HAProxy (TCP passthrough) → here (TLS terminate) → localhost:kanidm
#
#  Cert strategy: wildcard *.doggett.family so sso.doggett.family never appears
#  in CT logs. Porkbun DNS-01 challenge, same as estel. Each host manages its
#  own cert independently; both are valid *.doggett.family certs.
#
###############################################################################

{
  lib,
  config,
  configVars,
  ...
}:
let
  serviceBlacklist = configVars.homepage.serviceBlacklist or [ ];

  resolveServicePort =
    serviceName:
    let
      portFromNetworking = lib.attrByPath [ serviceName ] null configVars.networking.ports.tcp;
      portFromServiceConfig = lib.findFirst (port: port != null) null [
        (lib.attrByPath [ "services" serviceName "port" ] null config)
        (lib.attrByPath [ "services" serviceName "listenPort" ] null config)
        (lib.attrByPath [ "services" serviceName "settings" "Port" ] null config)
        (lib.attrByPath [ "services" serviceName "settings" "port" ] null config)
      ];
      resolvedPort = if portFromNetworking != null then portFromNetworking else portFromServiceConfig;
    in
    if resolvedPort == null then null else builtins.toString resolvedPort;

  # Services hosted on feanor. Grows as stacks move off cirdan.
  feanorServices = [
    "jellyfin"
  ];

  visibleServices = lib.filter (svc: !(lib.elem svc serviceBlacklist)) feanorServices;

  localHomepageServices = lib.filter (svc: svc.port != null) (
    map (svc: {
      service = svc;
      port = resolveServicePort svc;
    }) visibleServices
  );

  localServiceLinks = lib.sort (a: b: a.name < b.name) (
    map (svc: {
      name = svc.service;
      url = "http://${config.networking.hostName}.${configVars.homeLanDomain}:${svc.port}";
    }) localHomepageServices
  );
in
{
  services.homelab-status-page.serviceLinks = localServiceLinks;

  ##################### Caddy + ACME wildcard cert ############################
  #
  # Caddy manages the *.doggett.family wildcard cert via Porkbun DNS-01.
  # Kanidm reads the cert directly from /var/lib/acme/wild-${configVars.homeDomain}/
  # (kanidm.nix adds kanidm to the "caddy" group so it can read cert files).
  #
  # estel's Caddy is the public-facing TLS terminator for the kanidm subdomain;
  # it proxies over the LAN to feanor's Kanidm port. Feanor's Caddy doesn't
  # serve any public virtual hosts, so no ports need to be opened on the firewall.
  # DNS-01 challenge does not require ports 80 or 443 to be reachable.

  services.caddy.enable = true;

  ############################ ACME / Porkbun ##################################

  security.acme.acceptTerms = true;
  security.acme.defaults.email = configVars.email.letsencrypt;

  sops.secrets."porkbun/dns-failover/key" = { };
  sops.secrets."porkbun/dns-failover/secret" = { };

  sops.templates."acme-porkbun-secrets.env" = {
    content = ''
      PORKBUN_API_KEY=${config.sops.placeholder."porkbun/dns-failover/key"}
      PORKBUN_SECRET_API_KEY=${config.sops.placeholder."porkbun/dns-failover/secret"}
    '';
    owner = "caddy";
  };

  security.acme.certs."wild-${configVars.homeDomain}" = {
    domain = "*.${configVars.homeDomain}";
    extraDomainNames = [ configVars.homeDomain ];
    group = "caddy";
    dnsProvider = "porkbun";
    environmentFile = config.sops.templates."acme-porkbun-secrets.env".path;
  };
}
