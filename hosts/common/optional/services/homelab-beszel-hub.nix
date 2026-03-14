{
  lib,
  config,
  pkgs,
  configVars,
  ...
}:

{
  # Homelab Beszel Hub - Lightweight monitoring dashboard
  # The hub is the central server that collects metrics from agents
  # Access via web UI to view all monitored systems
  # Namespaced as "homelab-" to avoid conflicts with future official nixpkgs module

  # Create beszel data directory
  systemd.tmpfiles.rules = [
    "d /var/lib/beszel 0750 root root - -"
  ];

  # Beszel hub Docker container (using upstream image name)
  virtualisation.oci-containers.containers.homelab-beszel = {
    image = "henrygd/beszel:latest";
    autoStart = true;
    ports = [
      "127.0.0.1:8090:8090" # Web UI (bind to localhost, proxy via Caddy)
    ];
    volumes = [
      "/var/lib/beszel:/beszel_data"
    ];
    environment = {
      # Set timezone
      TZ = "America/New_York";
    };
    extraOptions = [
      "--pull=always" # Always pull latest image on restart
    ];
  };

  # Open firewall for agent connections
  # Agents connect to hub on port 8090
  networking.firewall.allowedTCPPorts = lib.mkIf config.networking.firewall.enable [
    8090 # Beszel hub
  ];

  # Persistence for beszel data (optional - only active if impermanence is enabled)
  environment.persistence."${configVars.persistFolder}".directories = [
    "/var/lib/beszel"
  ];
}
