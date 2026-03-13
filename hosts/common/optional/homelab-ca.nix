{
  lib,
  config,
  configVars,
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

  # Install the CA certificate in the system trust store
  security.pki.certificateFiles = [
    config.sops.secrets."homelab-ssl/ca/cert".path
  ];
}
