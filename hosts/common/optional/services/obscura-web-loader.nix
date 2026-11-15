{
  config,
  lib,
  pkgs,
  ...
}:

# This is so that Open-WebUI can use obscura, which doesn't have a fully-defined
# external web loader interface. It sets up a local service that Open-WebUI can
# communicate with to fetch web pages using obscura.

let
  cfg = config.services.obscuraWebLoader;
  python = pkgs.python3;
  server = ./obscura-web-loader.py;
in
{
  options.services.obscuraWebLoader = {
    enable = lib.mkEnableOption "Obscura-backed Open-WebUI URL loader";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7760;
      description = "Loopback port for the Open-WebUI external web loader.";
    };

    fetchTimeout = lib.mkOption {
      type = lib.types.ints.between 5 120;
      default = 25;
      description = "Maximum Obscura navigation time in seconds.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.unstable.obscura;
      defaultText = lib.literalExpression "pkgs.unstable.obscura";
      description = "Obscura package used to fetch pages.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.open-webui.environment = {
      WEB_LOADER_ENGINE = lib.mkDefault "external";
      EXTERNAL_WEB_LOADER_URL = lib.mkDefault "http://127.0.0.1:${toString cfg.port}/";
      EXTERNAL_WEB_LOADER_API_KEY = lib.mkDefault "";
    };

    systemd.services.obscura-web-loader = {
      description = "Obscura-backed Open-WebUI external URL loader";
      wantedBy = [ "multi-user.target" ];
      before = [ "open-webui.service" ];
      serviceConfig = {
        DynamicUser = true;
        RuntimeDirectory = "obscura-web-loader";
        RuntimeDirectoryMode = "0700";
        ExecStart = "${python}/bin/python3 ${server}";
        Restart = "on-failure";
        RestartSec = 2;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictSUIDSGID = true;
        CapabilityBoundingSet = "";
        Environment = [
          "OBSCURA_BIN=${cfg.package}/bin/obscura"
          "OBSCURA_FETCH_TIMEOUT=${toString cfg.fetchTimeout}"
          "OBSCURA_PORT=${toString cfg.port}"
        ];
      };
    };

    systemd.services.open-webui = {
      requires = [ "obscura-web-loader.service" ];
      after = [ "obscura-web-loader.service" ];
    };
  };
}
