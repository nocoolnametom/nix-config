{ lib, ... }:
{
  services.postgresql.enable = lib.mkDefault true;
  services.postgresql.settings.shared_preload_libraries = "pg_stat_statements";
  services.postgresql.settings."pg_stat_statements.track" = "all";

  # Postgre Auto-backup
  services.postgresqlBackup.enable = lib.mkDefault true;
  services.postgresqlBackup.databases = [ ]; # Mastodon auto-adds itself to this list
  services.postgresqlBackup.startAt = "*-*-01,15 01:15:00"; # On the 1st and 15th of the month at 1:15am
}
