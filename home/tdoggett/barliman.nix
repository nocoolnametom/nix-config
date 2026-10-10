{
  pkgs,
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
    common/core # required - remember to include a sops config below!

    #################### Host-specific Optional Configs ####################
    common/optional/sops.nix
    common/optional/flatpak.nix
    common/optional/git.nix
    common/optional/jj.nix
    common/optional/devenv.nix
    common/optional/notification-leds.nix
    common/optional/smolcoder.nix

    ############### Service Configurations (Enable below) #################
    common/optional/services/atuin.nix
    common/optional/services/gpg-agent.nix
    common/optional/services/smolcoder-web.nix
    common/optional/services/syncthing.nix

    # Hermes Agent - must be imported after inputs are available
    inputs.hermes-agent.homeManagerModules.default
  ];

  # Define the hermeswebui secret for home-manager sops-nix
  sops.secrets."homelab/kanidm/oidc/hermeswebui/client-secret" = {
    sopsFile = "${inputs.nix-secrets}/secrets.yaml";
  };

  # Hermes Agent configuration - runs under tdoggett user via home-manager
  services.hermes-agent = {
    enable = true;
    gateway.enable = true;

    # Use model definitions from my-sd-models' machineLLMs/barliman.nix
    # This ensures Hermes uses the same models as Ollama
    # Default to _qwen3.5 which is barliman's main model (qwen3.5-abliterated:35b)
    # Use primary coding model from my-sd-models' machinePrimaryLLMs/barliman.nix
    # Hermes is primarily a coding tool - code generation, refactoring, debugging
    settings.model.default = "ollama/${pkgs.my-sd-models.machinePrimaryLLMs.barliman.coding}";

    # The hermeswebui client secret is provided by the system-level sops config
    # In home-manager, we reference it differently
  };

  # Hermes dashboard secret - passed via environment variable
  home.sessionVariables.HERMES_DASHBOARD_OIDC_CLIENT_SECRET =
    config.sops.secrets."homelab/kanidm/oidc/hermeswebui/client-secret".path;

  programs.atuin.settings.sync_address = "http://${configVars.networking.subnets.estel.ip}:${
    toString configVars.networking.ports.tcp."atuin-sync"
  }";

  programs.git.settings.user.email = configVars.gitHubEmail;

  # Custom packages are already overlaid into the provided `pkgs`
  home.packages = with pkgs; [
    handbrake
  ];

  # Flatpaks
  services.flatpak.packages = [
    # Until I figure out how to do this headlessly, this is like Flowframes
    {
      appId = "io.github.tntwise.REAL-Video-Enhancer";
      origin = "flathub";
    }
    # Flat seal can help with file permissions
    {
      appId = "com.github.tchx84.Flatseal";
      origin = "flathub";
    }
  ];

  home = {
    stateVersion = "26.05";
    username = configVars.username;
    homeDirectory = lib.mkForce "/home/${configVars.username}";
    sessionVariables.TERM = lib.mkForce "xterm-256color";
    sessionVariables.TERMINAL = lib.mkForce "";
  };
}
