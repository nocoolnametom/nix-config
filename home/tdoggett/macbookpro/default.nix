{
  lib,
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
    ../common/optional/git.nix
  ];

  programs.git.userEmail = inputs.nix-secrets.email.work;

  programs.ssh.enable = false;

  programs.bash.initExtra = ''
    # >>> conda initialize >>>
    # !! Contents within this block are managed by 'conda init' !!
    __conda_setup="$('/Users/tdoggett/anaconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "/Users/tdoggett/anaconda3/etc/profile.d/conda.sh" ]; then
            . "/Users/tdoggett/anaconda3/etc/profile.d/conda.sh"
        else
            export PATH="/Users/tdoggett/anaconda3/bin:$PATH"
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
