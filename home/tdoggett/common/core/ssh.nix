{ ocConfig, ... }:
{
  programs.ssh = {
    enable = true;
    compression = true;
    addKeysToAgent = "yes";
    # TODO Check if sops placed the private key in $HOME/.ssh/, if so I may not need this directive
    #extraConfig = ''
    #  IdentityFile ${osConfig.sops.secrets."ssh/personal/id_ed25519".path}
    #'';
  };
}
