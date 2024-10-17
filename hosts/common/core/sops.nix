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
  # I'm pretty sure we can't load this on darwin!
  imports = [ inputs.sops-nix.nixosModules.sops ];

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
        owner = config.users.users.${configVars.username}.name;
        inherit (config.users.users.${configVars.username}) group;
        path = "${homeDirectory}/.config/sops/age/keys.txt";
      };

      # Root-level SSH key so that the root user can retrieve my private nix-secrets repo
      # There's a systemd service to ensure the /root/.ssh directory is properly 0700
      "root-github-key" = {
        key = "ssh/personal/id_ed25519";
        mode = "0600";
        owner = config.users.users.root.name;
        group = config.users.users.root.group;
      };
    };
  };

  # Ensure that root has the needed SSH key to retrieve my private nix-secrets repo
  system.activationScripts.sopsSetRootGithubKeyOwnwership =
    let
      sshFolder = "/root/.ssh";
      sshKeyPath = "${sshFolder}/id_ed25519";
      user = config.users.users.root.name;
      group = config.users.users.root.group;
    in
    ''
      mkdir -p ${sshFolder} || true
      cat ${config.sops.secrets.root-github-key.path} > ${sshKeyPath}
      chown -R ${user}:${group} ${sshFolder}
      chmod 700 ${sshFolder}
      chmod 600 ${sshKeyPath}
    '';

  # The containing folders are created as root and if this is the first ~/.config/ entry,
  # the ownership is busted and home-manager can't target because it can't write into .config...
  # FIXME: We might not need this depending on how https://github.com/Mic92/sops-nix/issues/381 is fixed
  system.activationScripts.sopsSetAgeKeyOwnwership =
    let
      ageFolder = "${homeDirectory}/.config/sops/age";
      user = config.users.users.${configVars.username}.name;
      group = config.users.users.${configVars.username}.group;
    in
    ''
      mkdir -p ${ageFolder} || true
      chown -R ${user}:${group} ${homeDirectory}/.config
    '';
}
