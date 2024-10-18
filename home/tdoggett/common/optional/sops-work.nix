# This is the Home Manager-level sops configuration for my work machine
{
  inputs,
  config,
  configVars,
  ...
}:

let
  secretspath = builtins.toString inputs.nix-secrets;
  secretsFile = "${secretspath}/secrets.yaml";
  homeDirectory = config.home.homeDirectory;
in
{
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    # This should have been placed by the system-level sops config
    age.keyFile = "${homeDirectory}/.config/sops/age/keys.txt";

    defaultSopsFile = "${secretsFile}";
    validateSopsFiles = false;

    secrets = {
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
    } // configVars.work.sops.secrets { inherit config; };
  };
}
