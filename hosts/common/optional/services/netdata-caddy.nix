{
  lib,
  config,
  configVars,
  ...
}:

{
  # Netdata Caddy Configuration - Serves netdata dashboard via HTTPS
  # This should be imported on estel (where netdata parent runs)

  # Requires: homelab-status-page.nix for SSL certs

  services.caddy.virtualHosts."estel.${configVars.homelabDomain}".extraConfig = lib.mkAfter ''
    # Override the status page - serve netdata dashboard at root
    handle {
      reverse_proxy 127.0.0.1:19999 {
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-For {remote}
        header_up Host {host}
      }
    }
  '';

  # Also serve at monitoring subdomain for easy access
  services.caddy.virtualHosts."monitoring.${configVars.homelabDomain}" = {
    extraConfig = ''
      # Proxy to netdata
      reverse_proxy 127.0.0.1:19999 {
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-For {remote}
        header_up Host {host}
      }

      # TLS configuration with our homelab certificates
      # Caddy automatically redirects HTTP to HTTPS when TLS is configured
      tls ${config.sops.secrets."homelab-ssl/${config.networking.hostName}/cert".path} ${
        config.sops.secrets."homelab-ssl/${config.networking.hostName}/key".path
      }
    '';
  };
}
