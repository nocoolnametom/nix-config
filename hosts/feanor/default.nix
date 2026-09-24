###############################################################################
#
#  Feanor - UGREEN DXP4800 Plus
#
#  Headless NAS replacing cirdan (Synology DSM). Intel Pentium Gold 8505,
#  4x SATA bays + 2x user M.2, 10GbE + 2.5GbE.
#
#  ---------------------------------------------------------------------------
#  Migration plan (cirdan -> feanor)
#  ---------------------------------------------------------------------------
#  Phase 1 (this file)   Base system, storage, Jellyfin native, Komodo for the
#                        hand-managed container layer.
#  Phase 2               Take over SMB serving from cirdan; repoint the
#                        consumers in hosts/common/optional/cirdan-smb-shares.nix.
#  Phase 3               Move the remaining cirdan docker stacks into Komodo.
#  Phase 4               Retire Authentik. Kanidm runs alongside it throughout
#                        (hosts/common/optional/services/kanidm.nix is already
#                        written); services move over one at a time via the
#                        services.ssoProvider option, and Authentik dies with
#                        cirdan rather than being migrated onto feanor.
#  Phase 5               Transliterate the settled Komodo stacks into arion.
#
#  ---------------------------------------------------------------------------
#  Hardware prerequisites - do these BEFORE installing
#  ---------------------------------------------------------------------------
#  1. Disable the BIOS watchdog (Ctrl+F12 at POST). It reboots the box after
#     ~180s when UGOS is not answering, which will kill the installer.
#  2. Leave the factory UGOS SSD physically in place. The unit only boots from
#     that internal NVMe slot, so the NixOS bootloader goes into its ESP. A
#     BIOS boot-order change then restores the stock NAS if needed.
#  3. Fit the RAM upgrade before doing anything else. 8 GB will not carry
#     Jellyfin + the container stack.
#
###############################################################################

{
  inputs,
  pkgs,
  lib,
  configLib,
  config,
  configVars,
  ...
}:
let
  hostName = configVars.networking.subnets.feanor.name;

  # Data pool mount point (btrfs RAID1 across the SATA bays).
  dataRoot = "/silmaril";
in
{
  imports = [
    ######################## Every Host Needs This ############################
    ./hardware-configuration.nix

    ########################### Impermanence ##################################
    ./persistence.nix

    ######################### Status Page Links ###############################
    ./caddy.nix

    ######################### SMB / NFS / WebDAV ##############################
    ./shares.nix

    ####################### Borg + offsite sync ###############################
    ./backup.nix

    ################### cirdan data migration (temporary) #####################
    # Rsync service + timer that copies all cirdan shares to the silmaril pool.
    # Remove this import once cirdan is retired and all data is verified.
    ./cirdan-sync.nix
  ]
  ++ (map configLib.relativeToRoot [
    #################### Required Configs ####################
    "hosts/common/core"

    #################### Hardware ####################
    "hosts/common/optional/io-latency-tuning.nix" # Keep reads responsive during writes

    #################### Host-specific Optional Configs ####################
    "hosts/common/optional/homelab-ca.nix" # Install homelab CA certificate
    "hosts/common/optional/homelab-status-page.nix"
    "hosts/common/optional/services/homelab-beszel-agent.nix"
    # Immich is NOT native yet - see the note in the Immich section below.
    "hosts/common/optional/services/jellyfin.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/systemd-failure-pushover.nix"
    "hosts/common/optional/services/tailscale.nix"
    "hosts/common/optional/foreign-binaries.nix"

    #################### Users to Create ####################
    "home/${configVars.username}/persistence/feanor.nix"
    "hosts/common/users/${configVars.username}"
  ]);

  networking.hostName = hostName;

  ############################# Hardware ######################################
  # hardware.ugreenNas is a NixOS module auto-imported from modules/nixos/ugreen-nas.nix;
  hardware.ugreenNas.enable = true;

  # diskiomon lights up bay LEDs on I/O and monitors SMART health
  # even without knowing interface names
  hardware.ugreenNas.leds.enable = true;
  hardware.ugreenNas.leds.diskiomon.enable = true;

  # netdevmon colours the network LED by link speed and gateway reachability.
  # TODO: confirm NIC interface names once the hardware is in hand.
  # The 10GbE is expected to be an Aquantia/Marvell atlantic device; the
  # 2.5GbE a Realtek RTL8125 (r8169).  Set interface and flip enable to
  # true once confirmed:
  # hardware.ugreenNas.leds.netdevmon.enable = true;
  #
  # replace with confirmed 10GbE interface
  # hardware.ugreenNas.leds.netdevmon.interface = "enp2s0";

  ############################## Storage ######################################
  #
  # The data pool is btrfs RAID1 (see hardware-configuration.nix for the disk
  # layout and the two-phase build). 33 TB usable while cirdan still holds a
  # copy, 46 TB once its last drive is folded in.
  #
  # Monthly scrub is the whole point of choosing a checksumming filesystem -
  # it is what turns "silent bitrot" into "repaired from the mirror".

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ dataRoot ];
  };

  ########################## I/O responsiveness ###############################
  #
  # The problem this solves, as seen on cirdan: streaming a show while an *arr
  # import lands a 20 GB file makes Jellyfin stutter for 10-15 minutes. That
  # is a scheduling failure, not a throughput one - see the long explanation
  # in hosts/common/optional/io-latency-tuning.nix.
  #
  # The writer here is smbd (durin's Radarr/Sonarr push over SMB) and the
  # reader is Jellyfin reading locally, so the weights can be lopsided.

  services.ioLatencyTuning = {
    enable = true;
    ioPriorities = {
      jellyfin = 1000; # 10x default: never starve a stream
      # immich-server = 200;  # re-enable when Immich goes native
      samba-smbd = 50; # bulk imports yield to everything above
      nfs-server = 50;
    };
  };

  ############################### Immich ######################################
  #
  # STAYS IN A CONTAINER FOR NOW. nixpkgs marks immich 2.7.5 insecure
  # (CVE-2026-59258, CVE-2026-82272) and both nixos-26.05 and nixos-unstable
  # are pinned to that same version, so there is no patched build to switch
  # to. Whitelisting it via permittedInsecurePackages on the box that holds
  # every photo we own is not a trade worth making; the container lets us
  # track upstream's patched release the day it lands.
  #
  # Re-check with:  nix eval nixpkgs#immich.version
  # When a fixed version ships, import
  # "hosts/common/optional/services/immich.nix" above and restore:
  #
  #   services.immich.mediaLocation = "${dataRoot}/immich";
  #   services.immich.host = "0.0.0.0";
  #   services.immich.accelerationDevices = lib.mkForce null;
  #
  # Either way the originals belong on the pool and the Postgres database on
  # the NVMe - databases on btrfs HDDs are the worst case for copy-on-write
  # fragmentation, and nodatacow would fix that only by disabling checksums,
  # which is the whole reason we chose btrfs.

  ############################## Syncthing ####################################

  services.syncthing = {
    enable = true;
    # Literal rather than config.users.groups.datadat.name: syncthing's module
    # defines a user, so reading users.groups here is a cycle.
    group = "datadat";
    dataDir = "${dataRoot}/syncthing";
    configDir = "/var/lib/syncthing"; # NVMe: small, write-heavy index DB
    # reverse-proxied; never bind this publicly
    guiAddress = "127.0.0.1:${toString configVars.networking.ports.tcp.syncthing}";
    openDefaultPorts = true; # 22000/tcp+udp for sync traffic itself
  };

  systemd.tmpfiles.rules = [
    "d ${dataRoot}/stacks 0770 root root -"
  ];

  ######################## Container Layer (Komodo) ###########################
  #
  # Komodo was chosen over Portainer and Dockge because it is the only one of
  # the three with native OIDC in its free build (Dockge has none by design;
  # Portainer gates full OIDC behind Business Edition), and because it keeps
  # every stack as a plain compose.yaml on disk - which is what makes the
  # eventual move to arion a transliteration rather than a database export.
  #
  # nixpkgs ships a module for the periphery agent only; Komodo Core itself
  # runs as a container. TODO: stand Core up once nix-secrets has the komodo
  # subdomain/port and the Kanidm OAuth2 client is provisioned.
  #
  # Even with OIDC in front of it, this stays off the public Internet - a
  # container manager is root-equivalent on the host. Tailscale only.

  # Deliberately NOT importing hosts/common/optional/services/docker.nix: it
  # publishes an unauthenticated, root-equivalent Docker API on 0.0.0.0:2375
  # and opens the firewall for it. Tolerable on durin; not on the box holding
  # every photo we own. Same settings minus the network socket:
  virtualisation.docker.enable = true;
  virtualisation.docker.listenOptions = [ "/run/docker.sock" ];
  virtualisation.docker.autoPrune = {
    enable = true;
    dates = "weekly";
    flags = [
      "--all"
      "--filter"
      "until=168h"
    ];
  };
  users.users."${configVars.username}".extraGroups = [ "docker" ];

  ############################### Network #####################################
  #
  # Reaches the Internet the same way estel does: no ports opened at home,
  # outbound WireGuard to bombadil, HAProxy SNI routing on the far end.
  #
  # TODO: feanor is not yet a peer on the wg-homelab tunnel.
  # hosts/common/optional/services/wireguard-bombadil-estel.nix is hardcoded
  # to exactly two hosts and needs generalising before feanor can join. Until
  # then this box is reachable over Tailscale and the LAN only.

  # No NetworkManager here. It is the right tool for a laptop that roams
  # between networks; on a headless box with two fixed ethernet ports it just
  # drags in wpa_supplicant (NetworkManager force-enables networking.wireless
  # unless the iwd backend is selected - which is the only reason estel gets
  # away with setting both).
  #
  # TODO: confirm interface names on the real hardware. Expect the 10GbE to be
  # an Aquantia part (atlantic driver) and the 2.5GbE a Realtek RTL8125
  # (r8169). Give feanor a DHCP reservation on the router so its address
  # matches configVars.networking.subnets.feanor.ip.
  networking.useDHCP = lib.mkDefault true;
  networking.enableIPv6 = true;

  # Firewall stays on: nothing is port-forwarded to this machine.
  networking.firewall.enable = true;

  time.timeZone = "America/New_York";

  services.chrony.enable = true;
  services.chrony.enableNTS = true;
  services.chrony.servers = [ "time.cloudflare.com" ];

  # Headless.
  services.xserver.enable = false;

  services.journald.extraConfig = ''
    SystemMaxUse=500M
    RuntimeMaxUse=500M
  '';

  ############################### Alerting ####################################

  services.systemd-failure-alert.additional-services = [
    "docker"
    "jellyfin"
    "smartd"
  ];

  ########################### Automatic Upgrades ##############################
  #
  # Tracks flake *inputs* only - this never pulls main from the config repo.
  # Config changes land when you rebuild by hand, same as bombadil.
  #
  # allowReboot is off during bring-up: with root being wiped every boot, an
  # unattended 4am reboot is a bad time to discover a missing persistence
  # entry. Once the container layer has settled and persistence is proven,
  # flip it on with the rebootWindow below - an Internet-facing box that never
  # reboots is quietly accumulating unpatched kernel and openssl CVEs.

  system.autoUpgrade.enable = true;
  system.autoUpgrade.flake = inputs.self.outPath;
  system.autoUpgrade.allowReboot = false;
  system.autoUpgrade.rebootWindow = {
    lower = "04:00";
    upper = "05:00";
  };
  system.autoUpgrade.flags = [
    "--update-input"
    "nixpkgs"
    "--update-input"
    "nixpkgs-stable"
    "--update-input"
    "nixpkgs-unstable"
    "--no-write-lock-file"
    "-L"
  ];

  environment.systemPackages = with pkgs; [
    btrfs-progs
    curl
    git
    htop
    rsync
    samba
    tree
    wget
  ];

  services.fail2ban.enable = false; # No direct SSH from outside.

  system.stateVersion = "26.05";
}
