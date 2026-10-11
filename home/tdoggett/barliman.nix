{
  pkgs,
  lib,
  config,
  configVars,
  osConfig,
  inputs,
  ...
}:
let
  # Ollama's OpenAI-compatible endpoint, shared by the provider declaration
  # and anything else that needs to reach it.
  ollamaUrl = "http://127.0.0.1:${toString configVars.networking.ports.tcp.ollama}/v1";
in
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

  # Only the gateway's bearer key is secret. The dashboard's Kanidm login is a
  # public OIDC client (authorization-code + PKCE), so there is deliberately no
  # client secret here: upstream exposes only HERMES_DASHBOARD_OIDC_{ISSUER,
  # CLIENT_ID,SCOPES} for that provider. The old system module set a
  # HERMES_DASHBOARD_OIDC_CLIENT_SECRET, but no such variable exists in 0.21.5
  # - it was silently ignored while Kanidm, provisioned as a confidential
  # client, rejected the unauthenticated code exchange with 401.
  sops.secrets."homelab/hermes/api-server-key" = {
    sopsFile = "${inputs.nix-secrets}/secrets.yaml";
  };

  # The value has to reach the systemd *user* unit, which home.sessionVariables
  # cannot do (it only exports into interactive shells). Hermes reads this file
  # through environmentFiles, which activation folds into $HERMES_HOME/.env.
  sops.templates."hermes-agent.env".content = ''
    API_SERVER_KEY=${config.sops.placeholder."homelab/hermes/api-server-key"}
  '';

  # Hermes Agent configuration - runs under tdoggett user via home-manager
  services.hermes-agent = {
    enable = true;
    gateway.enable = true;

    # Local Ollama through its OpenAI-compatible endpoint.
    #
    # `provider` and `base_url` are both required. A bare
    # `default = "ollama/<model>"` is parsed as the short provider/model alias
    # form, and Hermes's built-in "ollama" provider means *ollama.com* - it
    # looks for OLLAMA_API_KEY and fails with "Hermes is not connected to any
    # AI provider yet", never touching the local server. "custom" plus an
    # explicit base_url is what points it at this machine.
    #
    # Model name comes from my-sd-models' machinePrimaryLLMs/barliman.nix;
    # Hermes is primarily a coding tool here, so it tracks the coding model.
    # Declare the endpoint as a named provider rather than leaning on the
    # inline `provider = "custom"` + base_url form. That inline form routes the
    # *default* model fine, but "custom" is not a declared provider, so picking
    # any other model in the dashboard failed with "Unknown provider 'custom'.
    # ... define it in config.yaml under 'providers:'". A real entry gives every
    # model on this endpoint a resolvable route, not just the startup default.
    # `discover_models` defaults to true, which is what populates the picker
    # from Ollama's live /v1/models list.
    settings.providers.ollama-local.api = ollamaUrl;

    settings.model = {
      provider = "ollama-local";
      default = pkgs.my-sd-models.machinePrimaryLLMs.barliman.coding;
      # Track whatever Ollama actually serves rather than restating it. The
      # retired system module used a 65536 constant, but there it was the
      # *floor* for an assertion ("Hermes refuses local model servers offering
      # under 64K tokens") - as a context_length it would instead cap Hermes at
      # a third of barliman's real 196608 window. Reading it from osConfig
      # keeps the two from drifting apart.
      context_length = lib.toInt (
        osConfig.services.ollama.environmentVariables.OLLAMA_CONTEXT_LENGTH or "65536"
      );
    };

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
