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
  programs.ssh.matchBlocks."${configVars.networking.external.elrond.name}".identityFile =
    config.sops.secrets."ssh/personal/id_ed25519".path;
  programs.ssh.matchBlocks."${configVars.networking.external.bombadil.mainUrl}".identityFile =
    config.sops.secrets."ssh/personal/id_ed25519".path;
  programs.ssh.matchBlocks."${configVars.networking.subnets.steamdeck}".identityFile =
    config.sops.secrets."ssh/personal/id_ed25519".path;
}
