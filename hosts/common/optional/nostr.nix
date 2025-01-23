{
  config,
  configVars,
  lib,
  ...
}:
let
  cfg = config.programs.nostr;
in
{
  options.programs.nostr = {
    enable = lib.mkEnableOption "Enable Nostr";
    domain = lib.mkOption {
      type = lib.types.str;
      default = configVars.domain;
      description = "Domain for serving Nostr identify";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."nostr_public_key_hex" = { };
    sops.templates."nostr.json" = {
      content = ''
        {
          "names": {
            "tom": "${config.sops.placeholder."nostr_public_key_hex"}"
          }
        }
      '';
      owner = "nginx";
    };

    services.nginx.virtualHosts."${cfg.domain}".locations."~* ^/.well-known/nostr.json" = {
      alias = config.sops.templates."nostr.json".path;
      extraConfig = ''
        add_header Access-Control-Allow-Origin * always;
        add_header Content-Type application/json;
        expires 30d;
        add_header Pragma public;
        add_header Cache-Control "public";
      '';
    };
  };
}
