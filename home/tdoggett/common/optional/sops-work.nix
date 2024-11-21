# This is the Home Manager-level sops configuration for my work machine - Can't be used WITH regular sops.nix!
{
  inputs,
  config,
  configVars,
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

  # This has to be manually placed as there is no system-level sops config to place it
  # The value can be found in the sops secrets file in the nix-secrets repo 
  sops.age.keyFile = lib.mkDefault "${homeDirectory}/.config/sops/age/keys.txt";

  sops.defaultSopsFile = "${secretsFile}";
  sops.validateSopsFiles = false;

  sops.secrets = lib.mkMerge [
    {
      "wakatime-key" = { };
      "ssh/personal/aws/fedibox" = {
        path = "${homeDirectory}/.ssh/id_fedibox";
        mode = "0600";
      };
      "ssh/personal/id_ed25519" = {
        mode = "0600";
        path = "${homeDirectory}/.ssh/personal_ed25519";
      };
      "ssh/yubikey/ykbackup" = {
        path = "${homeDirectory}/.ssh/id_ykbackup";
        mode = "0600";
      };
      "ssh/yubikey/ykkeychain" = {
        path = "${homeDirectory}/.ssh/id_ykkeychain";
        mode = "0600";
      };
      "ssh/yubikey/yklappy" = {
        path = "${homeDirectory}/.ssh/id_yklappy";
        mode = "0600";
      };
      "ssh/yubikey/ykmbp" = {
        path = "${homeDirectory}/.ssh/id_ykmbp";
        mode = "0600";
      };
    }
    (configVars.work.sops.secrets { inherit config; })
  ];
}
