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

  # Hermes needs the same two secrets the retired system-level service used
  # (hosts/common/optional/services/hermes-agent.nix, kept for reference).
  sops.secrets."homelab/hermes/api-server-key" = {
    sopsFile = "${inputs.nix-secrets}/secrets.yaml";
  };
  sops.secrets."homelab/kanidm/oidc/hermeswebui/client-secret" = {
    sopsFile = "${inputs.nix-secrets}/secrets.yaml";
  };

  # These have to arrive as values, not paths, and they have to reach the
  # systemd *user* units. home.sessionVariables does neither: it only exports
  # into interactive shells, so hermes-backend never saw the client secret and
  # came up with no auth provider at all.
  sops.templates."hermes-agent.env".content = ''
    API_SERVER_KEY=${config.sops.placeholder."homelab/hermes/api-server-key"}
    HERMES_DASHBOARD_OIDC_CLIENT_SECRET=${
      config.sops.placeholder."homelab/kanidm/oidc/hermeswebui/client-secret"
    }
  '';

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

    # Web dashboard. The module defaults to mode "none" on 127.0.0.1:9119, and
    # upstream only starts the dashboard's authentication gate for a
    # *non-loopback* bind - so the loopback default silently produced a
    # dashboard with auth_required=false and no providers, on a port estel's
    # Caddy does not proxy. Bind the LAN address on the hermeswebui port.
    backend = {
      mode = "dashboard";
      host = "0.0.0.0";
      port = configVars.networking.ports.tcp.hermeswebui;
    };
    settings.dashboard = {
      # Builds the OIDC callback (<public_url>/auth/callback) and is the only
      # Host header the DNS-rebinding guard accepts besides the bind address,
      # which is why proxying from estel needs both of these set.
      public_url = "https://${configVars.networking.subdomains.hermeswebui}.${configVars.domain}";
      trusted_proxies = [ configVars.networking.subnets.estel.ip ];
      oauth = {
        provider = "self-hosted";
        self_hosted = {
          issuer = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/hermeswebui";
          client_id = "hermeswebui";
        };
      };
    };

    # Gateway's OpenAI-style API, published by estel at <subdomains.hermes>.
    # Every client presents the same bearer API_SERVER_KEY; deliberately not
    # behind SSO because a login redirect would break Conduit.
    environment = {
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "0.0.0.0";
      API_SERVER_PORT = toString configVars.networking.ports.tcp.hermes;
    };
    environmentFiles = [ config.sops.templates."hermes-agent.env".path ];
  };

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
