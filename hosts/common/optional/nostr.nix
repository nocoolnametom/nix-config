{ config, configVars, ... }:
{

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

  services.nginx.virtualHosts."${configVars.domain}".locations."~* ^/.well-known/nostr.json" = {
    alias = config.sops.templates."nostr.json".path;
    extraConfig = ''
      add_header Access-Control-Allow-Origin * always;
      add_header Content-Type application/json;
      expires 30d;
      add_header Pragma public;
      add_header Cache-Control "public";
    '';
  };
}
