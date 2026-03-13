{
  lib,
  config,
  configVars,
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
      [11111111-2222-3333-4444-555555555555]
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

    config = {
      global = {
        # Memory mode for the parent (stores metrics from children)
        "memory mode" = "dbengine";
        "page cache size" = "128"; # MB
        "dbengine multihost disk space" = "2048"; # MB for all child nodes

        # History retention
        "history" = "86400"; # 24 hours in seconds
      };

      web = {
        # Bind to localhost so we can proxy via Caddy
        "bind to" = "127.0.0.1:19999";

        # Allow connections from localhost (Caddy)
        "allow connections from" = "localhost 127.0.0.1";

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
