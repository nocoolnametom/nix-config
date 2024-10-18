{
  lib,
  config,
  configVars,
  osConfig,
  inputs,
  ...
}:
{
  imports = [
    ########################## Required Configs ###########################
    ../common/core # required

    #################### Host-specific Optional Configs ####################
    ../common/optional/sops.nix
    ../common/optional/sops-work.nix
    ../common/optional/ssh-work.nix
    ../common/optional/git.nix
  ];

  programs.git.userEmail = configVars.email.work;

  # We don't have a system-level sops config on darwin, so we'll use the home-manager-level
  # sops config to set the age keyfile for sops (it's a bit circular, but it works)
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets."user_age_keys/${configVars.username}_${osConfig.networking.hostName}" = {
    path = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    mode = "0600";
  };

  programs.ssh.enable = false;

  programs.bash.initExtra = ''
    # >>> conda initialize >>>
    # !! Contents within this block are managed by 'conda init' !!
    __conda_setup="$('${config.home.homeDirectory}/anaconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "${config.home.homeDirectory}/anaconda3/etc/profile.d/conda.sh" ]; then
            . "${config.home.homeDirectory}/anaconda3/etc/profile.d/conda.sh"
        else
            export PATH="${config.home.homeDirectory}/anaconda3/bin:$PATH"
        fi
    fi
    unset __conda_setup
    # <<< conda initialize <<<

    #THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
    export SDKMAN_DIR="$HOME/.sdkman"
    [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
  '';

  home = {
    stateVersion = "24.05";
    username = configVars.username;
    homeDirectory = lib.mkForce "/Users/${configVars.username}";
    sessionVariables.TERM = lib.mkForce "xterm-256color";
    sessionVariables.TERMINAL = lib.mkForce "";
  };
}
