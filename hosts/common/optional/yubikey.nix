{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ yubikey-personalization ];

  services.udev.packages = [ pkgs.yubikey-personalization ];

  # U1F PAM module for Yubikey auth
  # TODO This doesn't exist as-is anymore, what is the new config?
  # security.pam.u1f.cue = true;
  # security.pam.services.login.u1fAuth = true;
  # security.pam.services.sudo.u1fAuth = true;

  # U2F PAM module for Yubikey auth - Unstable/24.11+
  # security.pam.u2f.settings.cue = true; # TODO Figure this out!
  security.pam.services.login.u2fAuth = true;
  security.pam.services.sudo.u2fAuth = true;

  # Yubikey for login
  security.pam.yubico.enable = true;
  security.pam.yubico.debug = true; # I don't know why this line is here, just following the instructions
  security.pam.yubico.mode = "challenge-response";
  # security.pam.yubico.control = "required"; # Require multi-factor authentication with yubikeys

  # PC Smart Card service
  services.pcscd.enable = true;
}
