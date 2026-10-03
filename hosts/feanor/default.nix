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
    "hosts/common/optional/headless-server.nix"

    #################### Hardware ####################
    "hosts/common/optional/io-latency-tuning.nix" # Keep reads responsive during writes

    #################### Host-specific Optional Configs ####################
    "hosts/common/optional/homelab-ca.nix" # Install homelab CA certificate
    "hosts/common/optional/homelab-status-page.nix"
    "hosts/common/optional/services/homelab-beszel-agent.nix"
    "hosts/common/optional/services/kanidm.nix"
    "hosts/common/optional/services/docker.nix"
    "hosts/common/optional/services/docker/podfetch.nix"
    # TODO 2026-10-04: enable at cutover (with services.tubearchivist below),
    # after the 03:00 cirdan-sync has copied the media to /silmaril/tubearchivist
    # and the cirdan stack is stopped with its es/ and redis dump.rdb copied
    # over. Enabling it earlier starts TA on an empty Elasticsearch index.
    # "hosts/common/optional/services/docker/tubearchivist.nix"
    "hosts/common/optional/services/immich.nix"
    "hosts/common/optional/services/jellyfin.nix"
    "hosts/common/optional/services/openssh.nix"
    "hosts/common/optional/services/syncthing.nix"
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

  # Alder Lake UHD iGPU: Jellyfin transcode load shows up in Beszel.
  services.homelab-beszel-agent.enableIntelGpu = true;

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
      immich-server = 200;
      samba-smbd = 50; # bulk imports yield to everything above
      nfs-server = 50;
    };
  };

  ############################### Immich ######################################
  #
  # Service settings (unstable module/package, proxy trust, iGPU) live in
  # hosts/common/optional/services/immich.nix.
  #
  # The originals belong on the pool and the Postgres database on the NVMe
  # (/var/lib/postgresql) - databases on btrfs HDDs are the worst case for
  # copy-on-write fragmentation, and nodatacow would fix that only by
  # disabling checksums, which is the whole reason we chose btrfs.
  #
  # mediaLocation mirrors the container's UPLOAD_LOCATION, so the
  # upload/{upload,profile,backups} paths in backup.nix line up. Immich
  # (>= 1.136) rewrites the stored file paths on startup when it notices the
  # location moved from the container's /usr/src/app/upload.
  services.immich.mediaLocation = "${dataRoot}/immich/upload";

  ############################## Syncthing ####################################

  # Service settings live in hosts/common/optional/services/syncthing.nix.
  #
  # Access gates on the Syncthing tree. `datadat` is the limited-access group:
  # only syncthing itself, humans, and services explicitly cleared for limited
  # material (kavitan, via the datadat SMB login) may read gated folders.
  #   - Parents are 0751: traversable by any service configured with a full
  #     path (e.g. autocaliweb -> Library/Calibre), listable only by datadat,
  #     so even folder names stay hidden from other services.
  #   - Private/ and the game-save folders are 0750: no access outside datadat.
  # Modes below the gates do not matter. Syncthing has ignorePerms on, so it
  # never fights these, and tmpfiles reapplies them every boot.
  systemd.tmpfiles.rules = [
    "d ${dataRoot}/syncthing                         0751 syncthing datadat -"
    "d ${dataRoot}/syncthing/Sync                    0751 syncthing datadat -"
    "d ${dataRoot}/syncthing/Sync/Library            0751 syncthing datadat -"
    "d ${dataRoot}/syncthing/Sync/Library/Private    0750 syncthing datadat -"
    "d ${dataRoot}/syncthing/Sync/Ludusavi           0750 syncthing datadat -"
    "d ${dataRoot}/syncthing/Sync/DeckyCloudSaves    0750 syncthing datadat -"
    "d ${dataRoot}/stacks 0770 root root -"
  ];

  # Second lock for native general-audience services: even if one is ever
  # added to datadat by mistake, systemd hides the limited tree from it.
  systemd.services.jellyfin.serviceConfig.InaccessiblePaths = [
    "-${dataRoot}/syncthing/Sync/Library/Private"
  ];

  services.syncthing = {
    # Literal rather than config.users.groups.datadat.name: syncthing's module
    # defines a user, so reading users.groups here is a cycle.
    group = "datadat";
    dataDir = "${dataRoot}/syncthing";
  };


  ############################ Container services #############################
  # Modules live in hosts/common/optional/services/docker/; only where their
  # bulk data goes is feanor-specific.

  # Fresh install, not a migration from cirdan: subscriptions were re-added by
  # hand and cirdan's database and downloads were deliberately left behind.
  services.podfetch.podcastsDir = "${dataRoot}/podcasts";
  # Web login via Kanidm; existing `tdoggett` PodFetch user is matched by
  # preferred_username and keeps its password for GPodder clients.
  services.podfetch.useKanidm = true;

  # TODO 2026-10-04: uncomment with the tubearchivist import above.
  # services.tubearchivist.mediaDir = "${dataRoot}/tubearchivist/media";

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

  # The shared docker.nix publishes an unauthenticated, root-equivalent
  # Docker API on 0.0.0.0:2375 by default. Tolerable elsewhere; not on the
  # box holding every photo we own.
  virtualisation.dockerTcpApi.enable = false;

  ############################## SSO / Kanidm #################################
  #
  # Kanidm runs here so SSO survives the eventual retirement of cirdan without
  # any data migration. Public ingress follows the same path as every other
  # homelab service: bombadil → (WireGuard) → estel Caddy → feanor LAN IP.
  # No WireGuard changes needed; estel already has LAN connectivity to feanor.
  #
  # Before rebuilding, ensure feanor's age key can decrypt in nix-secrets:
  #   - all homelab/kanidm/* secrets
  #   - homelab-ssl/feanor/{cert,key} (Kanidm's TLS cert; see kanidm.nix)
  services.kanidmSso.enable = true;

  ############################### Network #####################################
  #
  # Public services reach the Internet via bombadil → estel (WireGuard).
  # Feanor itself is NOT a WireGuard peer; estel reaches it over the LAN.

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


  ############################### Alerting ####################################

  services.systemd-failure-alert.additional-services = [
    "docker"
    "immich-machine-learning"
    "immich-server"
    "jellyfin"
    "postgresql"
    "smartd"
  ];

  ########################### Automatic Upgrades ##############################
  #
  # Schedule and flags come from hosts/common/optional/headless-server.nix.
  #
  # allowReboot is off during bring-up: with root being wiped every boot, an
  # unattended 4am reboot is a bad time to discover a missing persistence
  # entry. Once the container layer has settled and persistence is proven,
  # flip it on with the rebootWindow below - an Internet-facing box that never
  # reboots is quietly accumulating unpatched kernel and openssl CVEs.

  system.autoUpgrade.allowReboot = false;
  system.autoUpgrade.rebootWindow = {
    lower = "04:00";
    upper = "05:00";
  };

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

  # Links on this host's homelab status page.
  services.homelab-status-page.localServices = [
    "immich"
    "jellyfin"
  ];

  system.stateVersion = "26.05";
}
