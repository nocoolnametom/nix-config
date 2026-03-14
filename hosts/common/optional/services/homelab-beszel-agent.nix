{
  lib,
  config,
  configVars,
  pkgs,
  ...
}:

{
  # Homelab Beszel monitoring agent - connects to hub on estel
  # Lightweight alternative to Netdata for clean, focused system monitoring
  # Namespaced as "homelab-" to avoid conflicts with future official nixpkgs module

  # Universal token for agent self-registration
  sops.secrets."homelab/beszel/universal-token" = {
    owner = "beszel-agent";
    group = "beszel-agent";
  };

  services.homelab-beszel-agent = {
    enable = lib.mkDefault true;
    hubUrl = lib.mkDefault "http://${configVars.networking.subnets.estel.ip}:8090";
    tokenFile = lib.mkDefault config.sops.secrets."homelab/beszel/universal-token".path;
    sshKeyFile = lib.mkDefault (
      pkgs.writeText "beszel-hub-pubkey" ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJd98kvlC4Hsoiq4JFMHALy3J5Clj7eZ6GpRvj59pZDd
      ''
    );

    # Monitor common critical services (auto-detected based on what's enabled)
    monitoredServices = lib.mkDefault (
      lib.optional config.services.openssh.enable "sshd"
      ++ lib.optional config.services.nginx.enable "nginx"
      ++ lib.optional config.services.caddy.enable "caddy"
      ++ lib.optional config.services.postgresql.enable "postgresql"
      ++ lib.optional config.services.mysql.enable "mysql"
      ++ lib.optional config.virtualisation.docker.enable "docker"
      ++ lib.optional config.services.tailscale.enable "tailscaled"
      ++ lib.optional config.networking.firewall.enable "firewall"
    );

    # Enable GPU monitoring on systems with NVIDIA or AMD GPUs
    monitorGpu = lib.mkDefault (
      config.hardware.nvidia.package != null || config.hardware.amdgpu.opencl.enable or false
    );
  };
}
