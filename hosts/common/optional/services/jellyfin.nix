{
  lib,
  config,
  pkgs,
  ...
}:
{
  services.jellyfin.enable = lib.mkDefault true;
  services.jellyfin.openFirewall = lib.mkDefault true;

  # NOTE: the NixOS module hardcodes Jellyfin's HTTP port to 8096; it is not an
  # option, so configVars.networking.ports.tcp.jellyfin is only useful to the
  # reverse proxy in front of it.

  # Media lives on the shared data group, same as audiobookshelf/kavita.
  # `render` and `video` are what let it reach the iGPU for transcoding.
  users.users.jellyfin.extraGroups = [
    config.users.groups.datadat.name
    "render"
    "video"
  ];

  # Hardware transcoding via VAAPI / Quick Sync.
  #
  # On the Alder Lake iGPU in the DXP4800 Plus (Pentium Gold 8505) this covers
  # H.264 and HEVC encode+decode. AV1 is decode-only on this generation - an
  # AV1 source transcoding to anything else will still hit the GPU, but
  # transcoding *to* AV1 falls back to CPU and will be miserable.
  hardware.graphics.enable = lib.mkDefault true;
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # iHD - Broadwell and newer
    vpl-gpu-rt # oneVPL runtime, the modern QSV path
    intel-compute-runtime # OpenCL, used for tone mapping
  ];
}
