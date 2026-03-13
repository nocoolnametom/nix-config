{
  lib,
  config,
  configVars,
  ...
}:

{
  # Netdata Child Node - Streams metrics to the parent node (estel)
  # This should be imported on all monitoring targets (barliman, durin, pangolin11, smeagol)

  # Use the same API key as the parent
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
          destination = ${configVars.networking.subnets.estel.ip}:19999
          api key = ${config.sops.placeholder."netdata-stream-api-key"}
          timeout seconds = 60
          default port = 19999
          send charts matching = *
          enable compression = yes

          # Buffer sizes for streaming
          buffer size bytes = 10485760
          reconnect delay seconds = 5
          initial clock resync iterations = 60
    '';
    owner = "netdata";
    mode = "0600";
  };

  services.netdata = {
    enable = true;

    config = {
      global = {
        # Child nodes use RAM mode (data is streamed, not stored locally)
        "memory mode" = "ram";

        # Small history since we're streaming to parent
        "history" = "3600"; # 1 hour

        # Disable local web interface on child nodes (access via parent)
        "mode" = "normal";
      };

      web = {
        # Still bind web interface but don't need to expose it
        # The parent will show this node's metrics
        "bind to" = "127.0.0.1:19999";
      };
    };
  };

  # Link the templated stream.conf into netdata's config directory
  systemd.services.netdata.preStart = lib.mkAfter ''
    mkdir -p /var/lib/netdata/conf.d
    ln -sf ${config.sops.templates."netdata-stream.conf".path} /var/lib/netdata/conf.d/stream.conf
  '';

  # No firewall changes needed - child connects to parent, not vice versa
}
