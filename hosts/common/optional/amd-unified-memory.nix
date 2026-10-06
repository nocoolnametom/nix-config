###############################################################################
#
#  AMD APU unified memory (Strix Halo / Ryzen AI Max and similar)
#
#  These chips have no separate VRAM: the GPU uses system RAM through two pools.
#    * "VRAM": a fixed carve-out set in the BIOS, invisible to the OS forever.
#    * GTT: ordinary system RAM the GPU borrows on demand and gives back when
#      it's done. The kernel caps it at ttm.pages_limit, which defaults to
#      about half of the RAM the OS can see.
#
#  AMD recommends a minimal BIOS carve-out (0.5 GB) plus a raised GTT limit:
#  https://rocmdocs.amd.com/en/develop/how-to/system-optimization/strixhalo.html
#  That way the GPU can hold much larger models, and the memory is still
#  usable by the OS whenever no model is loaded.
#
#  Set the BIOS carve-out to its minimum BEFORE enabling this. A large
#  carve-out plus a raised limit lets the GPU request more RAM than the OS
#  actually has.
#
###############################################################################

{ config, lib, ... }:
let
  cfg = config.hardware.amdUnifiedMemory;
  # ttm.pages_limit is counted in 4 KiB pages: 1 GiB = 262144 pages
  pagesPerGiB = 262144;
in
{
  options.hardware.amdUnifiedMemory.gpuMemoryGiB = lib.mkOption {
    type = lib.types.nullOr lib.types.ints.positive;
    default = null;
    example = 52;
    description = ''
      Maximum system RAM (GiB) the GPU may borrow as GTT. Leave enough for the
      OS and other services. null keeps the kernel default (about half of RAM).
    '';
  };

  config = lib.mkIf (cfg.gpuMemoryGiB != null) {
    boot.kernelParams = [
      "ttm.pages_limit=${toString (cfg.gpuMemoryGiB * pagesPerGiB)}"
      # Let the page pool cache up to the same amount, so freed GPU memory is
      # reused quickly instead of going back to the OS on every allocation
      "ttm.page_pool_size=${toString (cfg.gpuMemoryGiB * pagesPerGiB)}"
    ];
  };
}
