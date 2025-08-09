{ lib, pkgs, ... }:
{
  services.wivrn.enable = lib.mkDefault true;
  services.wivrn.openFirewall = lib.mkDefault true;

  # Write information to /etc/xdg/openxr/1/active_runtime.json, VR applications
  # will automatically read this and work with WiVRn (Note: This does not currently
  # apply for games run in Valve's Proton)
  services.wivrn.defaultRuntime = lib.mkDefault true;

  # Run WiVRn as a systemd service on startup
  services.wivrn.autoStart = lib.mkDefault true;

  # Config for WiVRn (https://github.com/WiVRn/WiVRn/blob/master/docs/configuration.md)
  services.wivrn.config.enable = lib.mkDefault true;
  # 1.0x foveation scaling
  services.wivrn.config.json.scale = lib.mkDefault 1.0;
  # 100 Mb/s
  services.wivrn.config.json.bitrate = lib.mkDefault 100000000;
  services.wivrn.config.json.encoders = lib.mkDefault [
    {
      encoder = "vaapi";
      codec = "h265";
      # 1.0 x 1.0 scaling
      width = 1.0;
      height = 1.0;
      offset_x = 0.0;
      offset_y = 0.0;
    }
  ];
  # Deliver the screen to the VR headset
  services.wivrn.config.json.application = [ pkgs.wlx-overlay-s ];

  # Add env varible to steam
  programs.steam.package = lib.mkDefault (
    pkgs.steam.override (prev: {
      extraEnv = {
        PRESSURE_VESSEL_FILESYSTEMS_RW = "$XDG_RUNTIME_DIR/wivrn/comp_ipc";
      }
      // (prev.extraEnv or { });
    })
  );

  # Systemd variables for WiVRn
  services.wivrn.monadoEnvironment.IPC_EXIT_ON_DISCONNECT = lib.mkDefault "off";
  services.wivrn.monadoEnvironment.STEAMVR_LH_ENABLE = lib.mkDefault "1";
  services.wivrn.monadoEnvironment.XRT_COMPOSITOR_COMPUTE = lib.mkDefault "1";
  services.wivrn.monadoEnvironment.XRT_COMPOSITOR_LOG = lib.mkDefault "debug";
  services.wivrn.monadoEnvironment.XRT_PRINT_OPTIONS = lib.mkDefault "on";
  # If hand tracking is causing issues we can disable it:
  # services.wivrn.monadoEnvironment.WMR_HANDTRACKING = lib.mkDefault "0";

  # Need Git LFS for hand tracking data
  programs.git.enable = lib.mkDefault true;
  programs.git.lfs.enable = lib.mkDefault true;
}
