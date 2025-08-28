{
  # Ombi Requesting Server
  services.ombi.enable = true;

  services.postgresql.enable = true;
  services.postgresql.ensureDatabases = [ "ombi" ];
  services.postgresql.ensureUsers = [
    {
      name = "ombi";
      ensureDBOwnership = true;
    }
  ];
}
