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

    # Monitor all systemd services for comprehensive visibility
    # The wildcard catches any service consuming resources unexpectedly
    # Individual hosts can still override to add specific services they care about
    monitoredServices = lib.mkDefault [
      "*" # Monitor all services
    ];

    # Auto-detect additional filesystems from NixOS configuration
    # Monitors all mounted filesystems except root, boot, and virtual filesystems
    additionalFilesystems = lib.mkDefault (
      lib.filter (
        mountPoint:
        let
          fs = config.fileSystems.${mountPoint};
          # Exclude root, boot partitions, and virtual filesystems
          isVirtual = lib.elem fs.fsType [
            "tmpfs"
            "ramfs"
            "devtmpfs"
            "proc"
            "sysfs"
            "cgroup"
            "cgroup2"
          ];
          isBootOrRoot = lib.elem mountPoint [
            "/"
            "/boot"
            "/efi"
            "/boot/efi"
          ];
        in
        !isVirtual && !isBootOrRoot
      ) (lib.attrNames config.fileSystems)
    );

    # GPU monitoring is auto-detected by the agent - no configuration needed
    # Agent will automatically detect NVIDIA, AMD, and Intel GPUs if present
  };
}
