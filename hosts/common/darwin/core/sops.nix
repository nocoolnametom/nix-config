{
  pkgs,
  inputs,
  config,
  configVars,
  ...
}:

let
  secretspath = builtins.toString inputs.nix-secrets;
  secretsFile = "${secretspath}/secrets.yaml"; # The secrets file from the nix-secrets input

  homeDirectory =
    if pkgs.stdenv.isLinux then "/home/${configVars.username}" else "/Users/${configVars.username}";
in
{
  imports = [ inputs.sops-nix.darwinModules.sops ];

  environment.systemPackages = [ pkgs.sops ];

  sops = {
    defaultSopsFile = "${secretsFile}";
    validateSopsFiles = false;

    age = {
      # automatically import host SSH keys as age keys
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };

    secrets = {
      # For home-manager a separate age key is used to decrypt secrets and must be placed onto the host. This is because
      # the user doesn't have read permission for the ssh service private key. However, we can bootstrap the age key from
      # the secrets decrypted by the host key, which allows home-manager secrets to work without manually copying over
      # the age key.
      # These age keys are are unique for the user on each host and are generated on their own (i.e. they are not derived
      # from an ssh key).
      "user_age_keys/${configVars.username}_${config.networking.hostName}" = {
        owner = configVars.username;
        path = "${homeDirectory}/.config/sops/age/keys.txt";
      };

      # Root-level SSH key so that the root user can retrieve my private nix-secrets repo
      "ssh/personal/root_only/github" = {
        path = "/var/root/.ssh/id_ed25519";
        mode = "0600";
        owner = "root";
      };
    };
  };
}
