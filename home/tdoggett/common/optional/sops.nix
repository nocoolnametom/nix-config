# This is the Home Manager-level sops configuration - Can't be used WITH work-sops.nix!
{
  inputs,
  config,
  lib,
  ...
}:

let
  secretspath = builtins.toString inputs.nix-secrets;
  secretsFile = "${secretspath}/secrets.yaml";
  homeDirectory = config.home.homeDirectory;
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  # This should have been placed by the system-level sops config
  sops.age.keyFile = lib.mkDefault "${homeDirectory}/.config/sops/age/keys.txt";

  sops.defaultSopsFile = "${secretsFile}";
  sops.validateSopsFiles = false;

  sops.secrets."wakatime-key" = { };
  sops.secrets."ssh/personal/aws/fedibox" = {
    path = "${homeDirectory}/.ssh/id_fedibox";
    mode = "0600";
  };
  sops.secrets."ssh/personal/passphrased" = {
    path = "${homeDirectory}/.ssh/id_personal";
    mode = "0600";
  };
  sops.secrets."ssh/yubikey/ykbackup" = {
    path = "${homeDirectory}/.ssh/id_ykbackup";
    mode = "0600";
  };
  sops.secrets."ssh/yubikey/ykkeychain" = {
    path = "${homeDirectory}/.ssh/id_ykkeychain";
    mode = "0600";
  };
  sops.secrets."ssh/yubikey/yklappy" = {
    path = "${homeDirectory}/.ssh/id_yklappy";
    mode = "0600";
  };
  sops.secrets."ssh/yubikey/ykmbp" = {
    path = "${homeDirectory}/.ssh/id_ykmbp";
    mode = "0600";
  };
  sops.secrets."yubico/u2f_keys" = {
    path = "${homeDirectory}/.config/Yubico/u2f_keys";
    # mode = "0600";
  };
}
