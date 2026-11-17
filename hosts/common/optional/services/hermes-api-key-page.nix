{
  config,
  configVars,
  ...
}:
let
  port = configVars.networking.ports.tcp.hermes-api-key-page;
  apiBase = "https://${configVars.networking.subdomains.hermes}.${configVars.domain}";
  page = config.sops.templates."hermes-api-key-page.html".path;
in
{
  # The key hermes-agent.nix gives Hermes as API_SERVER_KEY. Anyone holding it can
  # make the agent run shell commands, so this page sits behind Kanidm SSO.
  sops.secrets."homelab/hermes/api-server-key" = { };
  sops.templates."hermes-api-key-page.html" = {
    content = ''
      <!doctype html>
      <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Hermes Agent API access</title>
          <style>
            :root { color-scheme: light; font-family: system-ui, sans-serif; background: #f3f5f2; color: #17231d; }
            body { max-width: 46rem; margin: 3rem auto; padding: 0 1.25rem; }
            h1 { font-size: 1.8rem; }
            section { border-top: 1px solid #b8c5bd; padding: 1rem 0; }
            code { overflow-wrap: anywhere; font-size: 1rem; }
            .key { padding: .8rem; background: #e2e9e4; border-radius: 4px; }
            .copy { margin-left: .5rem; padding: .3rem .6rem; cursor: pointer; min-width: 2.5rem; min-height: 2.5rem; display: inline-flex; align-items: center; justify-content: center; vertical-align: middle; }
            #copy-status { margin-left: .5rem; font-size: .9rem; }
          </style>
        </head>
        <body>
          <h1>Hermes Agent API access</h1>
          <section>
            <h2>OpenAI-compatible API base URL</h2>
            <p><code>${apiBase}/v1</code></p>
          </section>
          <section>
            <h2>Static API key</h2>
            <p class="key"><code id="api-key">${
              config.sops.placeholder."homelab/hermes/api-server-key"
            }</code>
              <button type="button" id="copy-key" class="copy" aria-label="Copy API key to clipboard" title="Copy API key"><svg width="18" height="18" viewBox="0 0 115.77 122.88" fill="currentColor" aria-hidden="true" focusable="false"><path fill-rule="evenodd" clip-rule="evenodd" d="M89.62,13.96v7.73h12.19h0.01v0.02c3.85,0.01,7.34,1.57,9.86,4.1c2.5,2.51,4.06,5.98,4.07,9.82h0.02v0.02 v73.27v0.01h-0.02c-0.01,3.84-1.57,7.33-4.1,9.86c-2.51,2.5-5.98,4.06-9.82,4.07v0.02h-0.02h-61.7H40.1v-0.02 c-3.84-0.01-7.34-1.57-9.86-4.1c-2.5-2.51-4.06-5.98-4.07-9.82h-0.02v-0.02V92.51H13.96h-0.01v-0.02c-3.84-0.01-7.34-1.57-9.86-4.1 c-2.5-2.51-4.06-5.98-4.07-9.82H0v-0.02V13.96v-0.01h0.02c0.01-3.85,1.58-7.34,4.1-9.86c2.51-2.5,5.98-4.06,9.82-4.07V0h0.02h61.7 h0.01v0.02c3.85,0.01,7.34,1.57,9.86,4.1c2.5,2.51,4.06,5.98,4.07,9.82h0.02V13.96L89.62,13.96z M79.04,21.69v-7.73v-0.02h0.02 c0-0.91-0.39-1.75-1.01-2.37c-0.61-0.61-1.46-1-2.37-1v0.02h-0.01h-61.7h-0.02v-0.02c-0.91,0-1.75,0.39-2.37,1.01 c-0.61,0.61-1,1.46-1,2.37h0.02v0.01v64.59v0.02h-0.02c0,0.91,0.39,1.75,1.01,2.37c0.61,0.61,1.46,1,2.37,1v-0.02h0.01h12.19V35.65 v-0.01h0.02c0.01-3.85,1.58-7.34,4.1-9.86c2.51-2.5,5.98-4.06,9.82-4.07v-0.02h0.02H79.04L79.04,21.69z M105.18,108.92V35.65v-0.02 h0.02c0-0.91-0.39-1.75-1.01-2.37c-0.61-0.61-1.46-1-2.37-1v0.02h-0.01h-61.7h-0.02v-0.02c-0.91,0-1.75,0.39-2.37,1.01 c-0.61,0.61-1,1.46-1,2.37h0.02v0.01v73.27v0.02h-0.02c0,0.91,0.39,1.75,1.01,2.37c0.61,0.61,1.46,1,2.37,1v-0.02h0.01h61.7h0.02 v0.02c0.91,0,1.75-0.39,2.37-1.01c0.61-0.61,1-1.46,1-2.37h-0.02V108.92L105.18,108.92z"/></svg></button>
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
