{
  pkgs,
  lib,
  configVars,
  ...
}:
{
  # Seerr — Jellyfin-aware requests manager (Jellyseerr's successor, renamed in nixpkgs 26.05).
  # Running alongside ombi during the transition.
  services.seerr.enable = lib.mkDefault true;
  services.seerr.port = configVars.networking.ports.tcp.seerr;
}
