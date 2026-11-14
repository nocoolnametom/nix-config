{
  config,
  configVars,
  ...
}:
let
  port = configVars.networking.ports.tcp.lemonade-api-key-page;
  estelIp = configVars.networking.subnets.estel.ip;
  apiBase = "https://${configVars.networking.subdomains.lemonade}.${configVars.domain}";
  page = config.sops.templates."lemonade-api-key-page.html".path;
in
{
  sops.secrets."homelab/lemonade/api-key" = { };
  sops.templates."lemonade-api-key-page.html" = {
    content = ''
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Lemonade API access</title>
          <style>
            :root { color-scheme: light; font-family: system-ui, sans-serif; background: #f3f5f2; color: #17231d; }
            body { max-width: 46rem; margin: 3rem auto; padding: 0 1.25rem; }
            h1 { font-size: 1.8rem; }
            section { border-top: 1px solid #b8c5bd; padding: 1rem 0; }
            code { overflow-wrap: anywhere; font-size: 1rem; }
            .key { padding: .8rem; background: #e2e9e4; border-radius: 4px; }
          </style>
        </head>
        <body>
          <h1>Lemonade API access</h1>
          <section>
            <h2>MCP endpoint</h2>
            <p><code>${apiBase}/mcp</code></p>
          </section>
          <section>
            <h2>OpenAI-compatible API base URL</h2>
            <p><code>${apiBase}/v1</code></p>
          </section>
          <section>
            <h2>Static API key</h2>
            <p class="key"><code>${config.sops.placeholder."homelab/lemonade/api-key"}</code></p>
            <p>Send it in the <code>Authorization: Bearer …</code> header.</p>
          </section>
        </body>
      </html>
    '';
    owner = "nginx";
    group = "nginx";
    mode = "0440";
  };

  services.nginx = {
    enable = true;
    virtualHosts."_" = {
      default = true;
      listen = [ { addr = "0.0.0.0"; inherit port; } ];
      extraConfig = ''
        allow ${estelIp};
        deny all;
      '';
      locations."= /" = {
        alias = page;
        extraConfig = "default_type text/html;";
      };
      locations."/".return = "404";
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}