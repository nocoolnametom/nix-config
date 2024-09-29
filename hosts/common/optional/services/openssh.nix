{ lib, ... }:
{
  services.openssh.enable = lib.mkDefault true;
  services.openssh.allowSFTP = lib.mkDefault false;
  services.openssh.settings.PermitRootLogin = lib.mkDefault "no";
  services.openssh.settings.PasswordAuthentication = lib.mkDefault false;
  services.openssh.settings.KbdInteractiveAuthentication = false;
  services.openssh.settings.X11Forwarding = lib.mkDefault false;
  services.openssh.settings.extraConfig = lib.mkDefault ''
    AllowTcpForwarding yes
    AllowAgentForwarding no
    AllowStreamLocalForwarding no
    AuthenticationMethods publickey
  '';
}
