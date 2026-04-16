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

  # Services hosted on smeagol (from the shared simpleServices list in estel/caddy.nix)
  smeagolServices = [
    "archerstash"
    "archerstashvr"
    "comfyui"
    "comfyuimini"
    "invokeai"
  ];

  visibleServices = lib.filter (svc: !(lib.elem svc serviceBlacklist)) smeagolServices;

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
}
