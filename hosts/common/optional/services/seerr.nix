{
  pkgs,
  lib,
  configVars,
  ...
}:
{
  # Seerr — Jellyfin-aware requests manager (Jellyseerr's successor, renamed in nixpkgs 26.05).
  # Full replacement for Ombi; requests.<homeDomain> redirects here (see hosts/estel/caddy.nix).
  services.seerr.enable = lib.mkDefault true;
  services.seerr.port = configVars.networking.ports.tcp.seerr;
}
