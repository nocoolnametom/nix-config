{ lib, ... }:
{
  # As of 2025-10-24 Jovian is trying to set this option that is no longer present
  options.services.logind.settings.Login.HandlePowerKey = lib.mkOption {
    type = lib.types.string;
    default = "";
  };
}
