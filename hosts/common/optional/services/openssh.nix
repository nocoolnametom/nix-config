{ lib, ... }:
{
  services.openssh.enable = lib.mkDefault true;
  services.openssh.settings.PermitRootLogin = lib.mkDefault "no";
  services.openssh.settings.PasswordAuthentication = lib.mkDefault false;
  services.openssh.settings.KbdInteractiveAuthentication = false;
}
