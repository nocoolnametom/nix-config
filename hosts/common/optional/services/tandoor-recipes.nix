{ lib, ... }: {
  services.tandoor-recipes.enable = lib.mkDefault true;
  services.tandoor-recipes.port = lib.mkDefault configVars.networking.ports.tcp.tandoor;
  services.tandoor-recipes.database.createLocally = lib.mkDefault true;
}
