# This is the Home Manager-level sops configuration for my work machine
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
        mode = "0600";
      };
      "ssh/work/id_ed25519" = {
        path = "${homeDirectory}/.ssh/id_ed25519";
        mode = "0600";
      };
    };
  };

  programs.ssh.matchBlocks."github.com".identityFile =
    config.sops.secrets."ssh/personal/id_ed25519".path;
  programs.ssh.matchBlocks."gitlab.com".identityFile =
    config.sops.secrets."ssh/personal/id_ed25519".path;
  programs.ssh.matchBlocks."elrond".identityFile = config.sops.secrets."ssh/personal/id_ed25519".path;
  programs.ssh.matchBlocks."exmormon.social".identityFile =
    config.sops.secrets."ssh/personal/id_ed25519".path;
  programs.ssh.matchBlocks."steamdeck".identityFile =
    config.sops.secrets."ssh/personal/id_ed25519".path;
}
