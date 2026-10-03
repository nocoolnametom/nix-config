###############################################################################
#
#  Headless server baseline
#
#  Shared by always-on machines with no desktop: no X, a capped journal,
#  NTS-authenticated time, and unattended upgrades of the flake's nixpkgs
#  inputs.
#
#  Auto-upgrade tracks flake *inputs* only - it never pulls new config from
#  the repo; config changes land when a host is rebuilt by hand. Reboot
#  policy (allowReboot / rebootWindow) stays per-host.
#
###############################################################################

{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.headlessServer;
in
{
  options.headlessServer.extraUpdateInputs = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "my-wordpress-plugins" ];
    description = "Flake inputs this host's auto-upgrade refreshes in addition to nixpkgs.";
  };

  config = {
    services.xserver.enable = lib.mkDefault false;

    services.journald.extraConfig = lib.mkDefault ''
      SystemMaxUse=500M
      RuntimeMaxUse=500M
    '';

    services.chrony.enable = lib.mkDefault true;
    services.chrony.enableNTS = lib.mkDefault true;
    services.chrony.servers = lib.mkDefault [ "time.cloudflare.com" ];

    system.autoUpgrade.enable = lib.mkDefault true;
    system.autoUpgrade.flake = inputs.self.outPath;
    system.autoUpgrade.flags =
      lib.concatMap
        (input: [
          "--update-input"
          input
        ])
        (
          [
            "nixpkgs"
            "nixpkgs-stable"
            "nixpkgs-unstable"
          ]
          ++ cfg.extraUpdateInputs
        )
      ++ [
        "--no-write-lock-file"
        "-L" # print build logs
      ];
  };
}
