# This is the Home Manager-level sops configuration
{ inputs, config, ... }:

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
        path = "${homeDirectory}/.ssh/id_ed25519";
        mode = "0600";
      };
      "yubico/u2f_keys" = {
        path = "${homeDirectory}/.config/Yubico/u2f_keys";
        # mode = "0600"; #TODO Find out if the yubico keys need specific permissions
      };
    };
  };
}
