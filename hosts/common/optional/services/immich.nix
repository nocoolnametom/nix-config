{
  config,
  inputs,
  lib,
  pkgs,
  configVars,
  ...
}:
{
  # Package AND module come from nixos-unstable. nixos-26.05 is stuck on
  # immich 2.7.5, marked insecure (CVE-2026-59258, CVE-2026-82272) and no
  # longer updated; unstable carries the 3.x series. The 26.05 module was
  # written against 2.x, so it is swapped out rather than fed a 3.x package.
  # Drop both overrides once the stable branch ships 3.x.
  disabledModules = [ "services/web-apps/immich.nix" ];
  imports = [ "${inputs.nixpkgs-unstable}/nixos/modules/services/web-apps/immich.nix" ];

  services.immich.enable = lib.mkDefault true;
  services.immich.package = lib.mkDefault pkgs.unstable.immich;
  services.immich.openFirewall = lib.mkDefault true;
  services.immich.host = lib.mkDefault "0.0.0.0";
  services.immich.port = configVars.networking.ports.tcp.immich;
  services.immich.accelerationDevices = lib.mkDefault null;

  # Public traffic arrives via estel's Caddy; trust its X-Forwarded-For so
  # Immich logs and rate-limits real client IPs rather than estel's.
  services.immich.environment.IMMICH_TRUSTED_PROXIES =
    lib.mkDefault configVars.networking.subnets.estel.ip;

  # VAAPI transcoding and ML on an iGPU (accelerationDevices = null allows
  # all devices; these groups grant the device-node permissions).
  users.users.immich.extraGroups = lib.mkIf config.services.immich.enable [
    "video"
    "render"
  ];
}
