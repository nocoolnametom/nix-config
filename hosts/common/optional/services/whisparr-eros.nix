{
  lib,
  configVars,
  ...
}:
{
  # Whisparr-Eros (V3) Adult Scene NZB Server
  # Distinct from `whisparr.nix`: V3 is the Radarr-derived line, V2 the
  # Sonarr-derived one, and they keep separate databases.
  services.whisparr-eros.enable = true;

  # dataDir is left at the module default (/var/lib/whisparr-eros); hosts with
  # a dedicated media pool override it in their own config, as durin does.

  # Both lines default to 6969 upstream, so pin this to its reserved port
  services.whisparr-eros.settings.server.port = configVars.networking.ports.tcp.whisparr-eros;

  # Ensure the whisparr-eros user is in the shared media group
  users.groups.media = { };
  users.users.whisparr-eros.extraGroups = [ "media" ];

  # Set umask so whisparr-eros creates group-writable files when moving/renaming
  systemd.services.whisparr-eros.serviceConfig.UMask = lib.mkForce "0002";
}
