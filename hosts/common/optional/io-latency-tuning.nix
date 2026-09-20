###############################################################################
#
#  I/O latency tuning for spinning-rust storage servers
#
#  Fixes the classic NAS failure mode: a large sequential write (an *arr
#  import, a big SMB copy) starves concurrent reads, so media streaming
#  stutters for as long as the write takes.
#
#  Three independent causes, addressed in order of how much they matter:
#
#  1. WRITEBACK AVALANCHES. Linux defaults let dirty pages grow to a
#     *percentage of RAM* (vm.dirty_ratio, 20%). On a 64 GB box that is ~13 GB
#     of dirty data dumped at the disks in one burst, and every read queued
#     behind it waits. Switching to fixed byte limits caps the burst at
#     something the disks can drain in a couple of seconds.
#
#  2. NO FAIRNESS BETWEEN READERS AND WRITERS. The default scheduler on
#     rotational disks does not distinguish a latency-sensitive reader from a
#     bulk writer. BFQ does, and is the only scheduler that honours the
#     per-service IOWeight settings below.
#
#  3. NO PRIORITY SIGNAL. Even with BFQ, nothing tells the kernel that
#     Jellyfin matters more than smbd. See `ioPriorities` below.
#
#  This is all OS-level. The SATA ports on these boxes are plain AHCI with no
#  cache or RAID silicon, and Synology's "SSD cache" is likewise a software
#  layer - there is no hardware feature here to switch on.
#
###############################################################################

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ioLatencyTuning;
in
{
  options.services.ioLatencyTuning = {
    enable = lib.mkEnableOption "I/O latency tuning for mixed read/write storage workloads";

    dirtyBytes = lib.mkOption {
      type = lib.types.int;
      default = 512 * 1024 * 1024;
      description = ''
        Hard ceiling on dirty page cache before writers block. Rule of thumb:
        a few seconds of sustained write throughput. Setting this unsets
        vm.dirty_ratio - the two are mutually exclusive.
      '';
    };

    dirtyBackgroundBytes = lib.mkOption {
      type = lib.types.int;
      default = 128 * 1024 * 1024;
      description = ''
        Point at which background writeback starts. Keep it well below
        dirtyBytes so flushing is continuous rather than bursty.
      '';
    };

    rotationalScheduler = lib.mkOption {
      type = lib.types.str;
      default = "bfq";
      description = ''
        I/O scheduler for rotational devices. bfq is what makes IOWeight work.
        mq-deadline is the lower-overhead alternative if bfq's CPU cost shows
        up on a weak processor, but it cannot do proportional weighting.
      '';
    };

    ioPriorities = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = { };
      example = {
        jellyfin = 1000;
        samba-smbd = 50;
      };
      description = ''
        Per-systemd-service IOWeight (1-10000, default 100). Higher wins
        contention. Give latency-sensitive readers a large number and bulk
        writers a small one. Requires the bfq scheduler to have any effect.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = lib.optional (cfg.rotationalScheduler == "bfq") "bfq";

    boot.kernel.sysctl = {
      "vm.dirty_bytes" = cfg.dirtyBytes;
      "vm.dirty_background_bytes" = cfg.dirtyBackgroundBytes;

      # Default 500 (5s) lets writes sit in cache long enough to clump into a
      # burst. Flushing more often keeps each batch small.
      "vm.dirty_expire_centisecs" = 300;
      "vm.dirty_writeback_centisecs" = 100;
    };

    # Rotational disks get the fair scheduler; NVMe keeps `none`, where the
    # device's own queue handles ordering better than the kernel can.
    services.udev.extraRules = ''
      ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", \
        ATTR{queue/scheduler}="${cfg.rotationalScheduler}"
      ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="none"
    '';

    systemd.services = lib.mapAttrs (_name: weight: {
      serviceConfig.IOWeight = weight;
    }) cfg.ioPriorities;

    environment.systemPackages = [ pkgs.sysstat ]; # iostat, for confirming it worked
  };
}
