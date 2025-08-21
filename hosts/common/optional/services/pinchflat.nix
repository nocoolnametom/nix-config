{
  lib,
  config,
  configVars,
  ...
}:
{
  sops.secrets."pinchflat/key-base" = { };
  services.pinchflat.enable = lib.mkDefault true;
  services.pinchflat.openFirewall = lib.mkDefault true;
  services.pinchflat.port = lib.mkDefault configVars.networking.ports.tcp.pinchflat;
  services.pinchflat.extraConfig = lib.mkDefault {
    UMASK = "000";
    ENABLE_IPV6 = true;
    YT_DLP_WORKER_CONCURRENCY = 1;
  };
  sops.templates."pinchflat-secrets.env" = {
    content = ''
      SECRET_KEY_BASE=${config.sops.placeholder."pinchflat/key-base"}
    '';
    owner = if (builtins.hasAttr "user" config.services.pinchflat) then config.services.pinchflat.user else "root";
  };
  services.pinchflat.secretsFile = lib.mkDefault config.sops.templates."pinchflat-secrets.env".path;
}
