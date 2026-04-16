{
  lib,
  config,
  pkgs,
  configVars,
  ...
}:

let
  cfg = config.services.homelab-status-page;

  # Generate hostname from system hostname and homelab domain
  # e.g., "estel" + homelabDomain = "estel.<homelabDomain>"
  statusPageHostname = "${config.networking.hostName}.${configVars.homelabDomain}";

  serviceLinksHtml =
    if cfg.serviceLinks == [ ] then
      ""
    else
      ''
        <div class="info" style="margin-top: 20px;">
          <h2 style="font-size: 1.3rem; color: #374151; margin-bottom: 12px;">Local Services</h2>
          <ul style="list-style: none; padding: 0; margin: 0; text-align: left;">
            ${lib.concatMapStringsSep "\n" (svc: ''
              <li style="margin: 8px 0;">
                <a href="${svc.url}" style="color: #2563eb; text-decoration: none; font-weight: 500;">${svc.name}</a>
              </li>
            '') cfg.serviceLinks}
          </ul>
        </div>
      '';

  # Simple HTML status page
  # Create a directory with index.html for Caddy's file_server
  statusPageContent = pkgs.runCommand "status-page" { } ''
        mkdir -p $out
        cat > $out/index.html <<'EOF'
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>${config.networking.hostName} Status</title>
            <style>
              * { margin: 0; padding: 0; box-sizing: border-box; }
              body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
              }
              .container {
                background: white;
                border-radius: 20px;
                padding: 60px 40px;
                box-shadow: 0 20px 60px rgba(0,0,0,0.3);
                text-align: center;
                max-width: 500px;
                width: 100%;
              }
              h1 {
                font-size: 2.5rem;
                color: #333;
                margin-bottom: 10px;
              }
              .hostname {
                font-size: 1.2rem;
                color: #667eea;
                margin-bottom: 30px;
              }
              .status {
                display: inline-block;
                background: #10b981;
                color: white;
                padding: 12px 30px;
                border-radius: 50px;
                font-weight: 600;
                margin: 20px 0;
              }
              .pulse {
                animation: pulse 2s infinite;
              }
              @keyframes pulse {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.7; }
              }
              .info {
                margin-top: 30px;
                padding-top: 30px;
                border-top: 1px solid #e5e7eb;
              }
              .info-item {
                margin: 10px 0;
                color: #6b7280;
              }
              .info-label {
                font-weight: 600;
                color: #374151;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <h1>✓ Online</h1>
              <div class="hostname">${statusPageHostname}</div>
              <div class="status pulse">● System Running</div>
              <div class="info">
                <div class="info-item">
                  <span class="info-label">Hostname:</span> ${config.networking.hostName}
                </div>
                <div class="info-item">
                  <span class="info-label">NixOS Version:</span> ${config.system.nixos.version or "N/A"}
                </div>
                <div class="info-item">
                  <span class="info-label">System:</span> ${pkgs.stdenv.hostPlatform.system}
                </div>
              </div>
              ${serviceLinksHtml}
            </div>
          </body>
          </html>
    EOF
  '';

  # Detect if Nginx is already enabled
  # We don't check services.caddy.enable here to avoid infinite recursion
  # (since we might enable Caddy in this module)
  hasNginx = config.services.nginx.enable or false;

  # Use Caddy if Nginx is not enabled
  useCaddy = !hasNginx;
in
{
  options.services.homelab-status-page = {
    serviceLinks = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name for the service link.";
            };
            url = lib.mkOption {
              type = lib.types.str;
              description = "URL for the service link.";
            };
          };
        }
      );
      default = [ ];
      description = "Local service links to render on the homelab status page.";
    };
  };

  config = lib.mkMerge [
    # Configure sops secrets for this host's SSL certificates (always enabled)
    {
      sops.secrets."homelab-ssl/${config.networking.hostName}/key" = {
        owner = if useCaddy then "caddy" else "nginx";
        mode = "0600";
      };
      sops.secrets."homelab-ssl/${config.networking.hostName}/cert" = {
        owner = if useCaddy then "caddy" else "nginx";
        mode = "0644";
      };
    }

    # Caddy configuration
    (lib.mkIf useCaddy {
      services.caddy.enable = true;
      services.caddy.virtualHosts.${statusPageHostname} = {
        extraConfig = ''
          # Serve status page
          root * ${statusPageContent}
          file_server

          # TLS configuration with our homelab certificates
          # Caddy automatically redirects HTTP to HTTPS when TLS is configured
          tls ${config.sops.secrets."homelab-ssl/${config.networking.hostName}/cert".path} ${
            config.sops.secrets."homelab-ssl/${config.networking.hostName}/key".path
          }
        '';
      };

      # Open firewall for HTTP and HTTPS
      networking.firewall.allowedTCPPorts = lib.mkIf config.networking.firewall.enable [
        80
        443
      ];
    })

    # Nginx configuration (if Nginx is already enabled and Caddy is not)
    (lib.mkIf (!useCaddy && hasNginx) {
      services.nginx.virtualHosts.${statusPageHostname} = {
        forceSSL = true;
        sslCertificate = config.sops.secrets."homelab-ssl/${config.networking.hostName}/cert".path;
        sslCertificateKey = config.sops.secrets."homelab-ssl/${config.networking.hostName}/key".path;

        locations."/" = {
          root = statusPageContent;
        };
      };

      # Open firewall for HTTP and HTTPS
      networking.firewall.allowedTCPPorts = lib.mkIf config.networking.firewall.enable [
        80
        443
      ];
    })
  ];
}
