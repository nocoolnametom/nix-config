{ lib, configVars, ... }: {
  services.paperless.enable = lib.mkDefault true;
  services.paperless.port = lib.mkDefault configVars.networking.ports.tcp.paperless;
}
