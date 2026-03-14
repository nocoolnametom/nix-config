{
  lib,
  config,
  configVars,
  pkgs,
  ...
}:

{
  # Netdata Parent Node - Collects metrics from all child nodes
  # This should be imported on estel (the central monitoring host)

  # Generate streaming API key from sops
  sops.secrets."netdata-stream-api-key" = {
    key = "homelab/netdata/stream-api-key";
    owner = "netdata";
    mode = "0600";
  };

  # Create stream.conf with the API key from sops
  sops.templates."netdata-stream.conf" = {
    content = ''
      [stream]
          enabled = yes
          destination =
          api key = ${config.sops.placeholder."netdata-stream-api-key"}
          enable compression = yes

      # Accept connections from all child nodes with valid API key
      # The section header must be the actual API key that children use
      [${config.sops.placeholder."netdata-stream-api-key"}]
          enabled = yes
          default history = 3600
          default memory mode = dbengine
          health enabled by default = auto
          allow from = *
    '';
    owner = "netdata";
    mode = "0600";
  };

  services.netdata = {
    enable = true;
    package = pkgs.netdata.override { withCloudUi = true; };

    config = {
      global = {
        # Memory mode for the parent (stores metrics from children)
        "memory mode" = "dbengine";
        "page cache size" = "128"; # MB
        "dbengine multihost disk space" = "2048"; # MB for all child nodes

        # History retention
        "history" = "86400"; # 24 hours in seconds

        # Use writable config directory for stream.conf
        "config directory" = "/var/lib/netdata/conf.d";
      };

      web = {
        # Bind to all interfaces to accept streaming from child nodes
        # Web dashboard is still proxied via Caddy
        "bind to" = "0.0.0.0:19999";

        # Allow connections from local network for both streaming and web access
        # Caddy runs on localhost, children connect from 192.168.0.0/24
        "allow connections from" = "localhost 127.0.0.1 192.168.0.*";

        # Enable gzip compression
        "enable gzip compression" = "yes";
      };
    };
  };

  # Link the templated stream.conf into netdata's config directory
  systemd.services.netdata.preStart = lib.mkAfter ''
    mkdir -p /var/lib/netdata/conf.d
    ln -sf ${config.sops.templates."netdata-stream.conf".path} /var/lib/netdata/conf.d/stream.conf
  '';

  # Open firewall for child nodes to connect
  networking.firewall.allowedTCPPorts = lib.mkIf config.networking.firewall.enable [
    19999 # Netdata streaming port
  ];
}
