{
  lib,
  pkgs,
  config,
  configVars,
  ...
}:
{
  services.openssh.enable = lib.mkDefault true;
  services.openssh.allowSFTP = lib.mkDefault false;
  services.openssh.settings.PermitRootLogin = lib.mkDefault "no";
  services.openssh.settings.PasswordAuthentication = lib.mkDefault false;
  services.openssh.settings.KbdInteractiveAuthentication = false;
  services.openssh.settings.X11Forwarding = lib.mkDefault false;
  services.openssh.settings.StreamLocalBindUnlink = lib.mkDefault "yes";
  services.openssh.settings.GatewayPorts = lib.mkDefault "clientspecified";
  services.openssh.settings.AllowUsers =
    lib.optionals (config.services.openssh.settings.PermitRootLogin != "no")
      [
        config.users.users.root.name
      ];
  services.openssh.settings.AllowGroups = lib.mkDefault [ "wheel" ];

  # yubikey login / sudo
  # NOTE: We use rssh because sshAgentAuth is old and doesn't support yubikey:
  # https://github.com/jbeverly/pam_ssh_agent_auth/issues/23
  # https://github.com/z4yx/pam_rssh
  security.pam.services.sudo =
    { config, ... }:
    {
      rules.auth.rssh = {
        order = config.rules.auth.ssh_agent_auth.order - 1;
        control = "sufficient";
        modulePath = "${pkgs.pam_rssh}/lib/libpam_rssh.so";
        settings.authorized_keys_command = pkgs.writeShellScript "get-authorized-keys" ''
          cat "/etc/ssh/authorized_keys.d/$1"
        '';
      };
    };
}
