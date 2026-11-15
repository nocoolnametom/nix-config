{
  config,
  configVars,
  ...
}:
let
  port = configVars.networking.ports.tcp.lemonade-api-key-page;
  apiBase = "https://${configVars.networking.subdomains.lemonade}.${configVars.homeDomain}";
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
            .copy { margin-left: .5rem; padding: .3rem .6rem; font-size: 1.2rem; cursor: pointer; min-width: 2.5rem; min-height: 2.5rem; }
            #copy-status { margin-left: .5rem; font-size: .9rem; }
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
            <p class="key"><code id="api-key">${config.sops.placeholder."homelab/lemonade/api-key"}</code>
              <button type="button" id="copy-key" class="copy" aria-label="Copy API key to clipboard" title="Copy API key">📋</button>
              <span id="copy-status" role="status" aria-live="polite"></span>
            </p>
            <p>Send it in the <code>Authorization: Bearer …</code> header.</p>
          </section>
          <script>
            (function () {
              var btn = document.getElementById("copy-key");
              var status = document.getElementById("copy-status");
              var key = document.getElementById("api-key").textContent.trim();
              function done(ok) {
                status.textContent = ok ? "Copied" : "Copy failed";
                setTimeout(function () { status.textContent = ""; }, 2000);
              }
              function fallback() {
                var area = document.createElement("textarea");
                area.value = key;
                area.setAttribute("readonly", "");
                area.style.position = "fixed";
                area.style.opacity = "0";
                document.body.appendChild(area);
                area.select();
                var ok = false;
                try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
                document.body.removeChild(area);
                done(ok);
              }
              btn.addEventListener("click", function () {
                if (navigator.clipboard && window.isSecureContext) {
                  navigator.clipboard.writeText(key).then(function () { done(true); }, fallback);
                } else {
                  fallback();
                }
              });
            })();
          </script>
        </body>
      </html>
    '';
    owner = "caddy";
    group = "caddy";
    mode = "0440";
  };

  # Loopback only: oauth2-proxy on this host is the sole client, so no firewall port.
  # Keyed by port (not 127.0.0.1) so it matches any Host header: oauth2-proxy
  # forwards the public hostname, which a 127.0.0.1 site would not match.
  services.caddy.virtualHosts.":${toString port}" = {
    extraConfig = ''
      bind 127.0.0.1
      root * ${builtins.dirOf page}
      rewrite * /${baseNameOf page}
      file_server
    '';
  };
}
