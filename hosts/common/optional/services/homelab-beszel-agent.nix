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
    # Monitors one mount point per physical disk (not every partition/subvolume)
    additionalFilesystems =
      let
        # Extract physical device name from partition
        # Examples: nvme0n1p2 -> nvme0n1, sda1 -> sda, mmcblk0p1 -> mmcblk0
        getPhysicalDevice =
          device:
          let
            # Remove /dev/ prefix and mapper/ prefix for encrypted devices
            devName = lib.removePrefix "mapper/" (lib.removePrefix "/dev/" device);
            # Use regex to strip partition suffix
            # Matches: (device name)(optional 'p')(partition number)
            # NVMe/MMC: nvme0n1p1 -> nvme0n1, mmcblk0p1 -> mmcblk0
            # SATA/SAS: sda1 -> sda, sdb2 -> sdb
            match = builtins.match "([a-z]+[0-9]+)(p?)[0-9]+" devName;
          in
          if match != null then builtins.elemAt match 0 else devName;

        # Get all non-virtual, non-root filesystems
        allFilesystems = lib.filterAttrs (
          mountPoint: fs:
          let
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
          !isVirtual && !isBootOrRoot && fs.device != null
        ) config.fileSystems;

        # Group filesystems by physical device
        # For each physical device, pick the first (alphabetically) mount point
        physicalDevices = lib.unique (
          lib.mapAttrsToList (
            _: fs: if lib.hasPrefix "/dev/" fs.device then getPhysicalDevice fs.device else null
          ) allFilesystems
        );

        # For each physical device, find the first mount point
        selectedMounts = lib.filter (x: x != null) (
          lib.forEach physicalDevices (
            physDev:
            let
              matchingMounts = lib.mapAttrsToList (
                mountPoint: fs:
                if lib.hasPrefix "/dev/" fs.device && getPhysicalDevice fs.device == physDev then
                  mountPoint
                else
                  null
              ) allFilesystems;
              validMounts = lib.filter (x: x != null) matchingMounts;
            in
            if validMounts != [ ] then lib.head validMounts else null
          )
        );
      in
      lib.mkDefault selectedMounts;

    # GPU monitoring is auto-detected by the agent - no configuration needed
    # Agent will automatically detect NVIDIA, AMD, and Intel GPUs if present
  };
}
