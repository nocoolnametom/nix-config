{
  lib,
  config,
  configVars,
  pkgs,
  ...
}:

{
  # Install homelab CA certificate system-wide
  # This allows all browsers and applications to trust certificates signed by our homelab CA
  # Works on both NixOS and Darwin systems

  # Configure sops to make the CA cert available
  sops.secrets."homelab-ssl/ca/cert" = {
    mode = "0644"; # Public cert, readable by all
  };

  # Install the CA certificate after sops decrypts it
  # We use a systemd service instead of security.pki.certificateFiles
  # because the sops secret doesn't exist at build time
  systemd.services.install-homelab-ca = {
    description = "Install Homelab CA Certificate";
    after = [ "sops-install-secrets.service" ];
    wants = [ "sops-install-secrets.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      # Wait for sops secret to be available
      if [ -f ${config.sops.secrets."homelab-ssl/ca/cert".path} ]; then
        # Create directory for additional CA certs
        mkdir -p /etc/ssl/certs

        # Copy CA cert to system trust store location
        cp -f ${config.sops.secrets."homelab-ssl/ca/cert".path} /etc/ssl/certs/homelab-ca.crt
        chmod 644 /etc/ssl/certs/homelab-ca.crt

        # Trigger certificate bundle update by touching the directory
        # This will cause programs to reload their cert stores
        touch /etc/ssl/certs

        echo "Homelab CA certificate installed successfully"
      else
        echo "Warning: Homelab CA certificate not found at ${
          config.sops.secrets."homelab-ssl/ca/cert".path
        }"
        exit 1
      fi
    '';
  };

}
