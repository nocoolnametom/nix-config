{ pkgs, lib, ... }:
{
  # Ombi Requesting Server
  services.ombi.enable = lib.mkDefault true;
  services.ombi.package = lib.mkDefault pkgs.unstable.ombi;

  services.postgresql.enable = lib.mkDefault true;
  services.postgresql.ensureDatabases = [ "ombi" ];
  services.postgresql.ensureUsers = [
    {
      name = "ombi";
      ensureDBOwnership = true;
    }
  ];
}
