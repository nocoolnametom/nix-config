###############################################################################
#
#  Hermes Agent (Nous Research) - self-hosted personal agent
#
#  Uses upstream's own NixOS module (flake input `hermes-agent`); this file only
#  sets defaults for this homelab. Override any `services.hermes-agent.*`
#  option from the host.
#
#  Two processes share one HERMES_HOME (sessions, memory, skills, cron jobs):
#
#  * `hermes gateway` (service hermes-agent) with its OpenAI-style API server.
#    Conduit's "Hermes Agent" mode talks to this. Published by estel's Caddy at
#    https://<subdomains.hermes>.<domain>. Auth: no user accounts - every
#    client sends the same bearer key, API_SERVER_KEY, and Hermes refuses to
#    start the API server without a strong one. Anyone holding that key can
#    make the agent run shell commands on this machine, so treat it like an
#    SSH key. Not behind SSO: a login redirect would break Conduit.
#
#  * `hermes dashboard` (service hermes-backend), the browser admin panel, at
#    https://<subdomains.hermeswebui>.<domain>. Hermes itself logs users in
#    through Kanidm with OIDC (client "hermeswebui", defined in kanidm.nix).
#    The two need separate hostnames because both use /api/... paths.
#
###############################################################################

{
  config,
  lib,
  inputs,
  configVars,
  ...
}:
let
  apiPort = configVars.networking.ports.tcp.hermes;
  dashboardPort = configVars.networking.ports.tcp.hermeswebui;
  dashboardUrl = "https://${configVars.networking.subdomains.hermeswebui}.${configVars.domain}";
  ollamaPort = configVars.networking.ports.tcp.ollama;
  # Hermes rejects local model servers that serve less than 64K tokens of
  # context: its system prompt and tool schemas alone need a large share.
  contextLength = 65536;
in
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  # Value: `openssl rand -hex 32` (Hermes requires 16+ characters). The same
  # value goes into Conduit.
  sops.secrets."homelab/hermes/api-server-key" = { };
  # Same value as the hermeswebui client in kanidm.nix
  sops.secrets."homelab/kanidm/oidc/hermeswebui/client-secret" = { };
  sops.templates."hermes-agent.env".content = ''
    API_SERVER_KEY=${config.sops.placeholder."homelab/hermes/api-server-key"}
    HERMES_DASHBOARD_OIDC_CLIENT_SECRET=${
      config.sops.placeholder."homelab/kanidm/oidc/hermeswebui/client-secret"
    }
  '';

  services.hermes-agent = {
    enable = lib.mkDefault true;

    # `settings` is freeform YAML that upstream merges with lib.recursiveUpdate,
    # not the module system, so lib.mkDefault/mkForce must NOT be used inside it:
    # they get written into config.yaml as {_type: override, ...} objects. A host
    # overrides a value by simply setting it.

    # Local Ollama through its OpenAI-compatible endpoint ("custom" provider)
    settings.model = {
      provider = "custom";
      base_url = "http://127.0.0.1:${toString ollamaPort}/v1";
      # MoE 35B / 3B active; tools + vision + thinking, so images sent from
      # Conduit work too. "_qwen3.5" is barliman's name for the abliterated
      # build (huihui_ai/qwen3.5-abliterated:35b), set up by ollama.nix from
      # my-sd-models' machineLLMs/barliman.nix
      default = "_qwen3.5";
      context_length = contextLength;
    };

    # Web dashboard. A non-loopback bind turns on Hermes's login gate, which
    # refuses to start without an auth provider - here Kanidm.
    backend = {
      mode = lib.mkDefault "dashboard";
      host = lib.mkDefault "0.0.0.0";
      port = lib.mkDefault dashboardPort;
    };
    settings.dashboard = {
      # Builds the OIDC callback (<public_url>/auth/callback) and is the only
      # Host header the DNS-rebinding guard accepts besides the bind address
      public_url = dashboardUrl;
      trusted_proxies = [ configVars.networking.subnets.estel.ip ];
      oauth = {
        provider = "self-hosted";
        self_hosted = {
          issuer = "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/hermeswebui";
          client_id = "hermeswebui";
        };
      };
    };

    environment = {
      API_SERVER_ENABLED = "true";
      # Bound to the LAN so estel's Caddy can reach it; the key gates every request
      API_SERVER_HOST = lib.mkDefault "0.0.0.0";
      API_SERVER_PORT = toString apiPort;
    };
    environmentFiles = [ config.sops.templates."hermes-agent.env".path ];
  };

  # Ollama has to actually serve the window Hermes is told about. This only
  # checks the value instead of setting it, so ollama.nix (or the host) stays the
  # one place that picks the context size. It must be set explicitly: when it's
  # unset, Ollama picks 4K, 32K or 256K depending on how much GPU memory it sees.
  assertions = lib.optional config.services.ollama.enable {
    assertion =
      lib.toInt (config.services.ollama.environmentVariables.OLLAMA_CONTEXT_LENGTH or "0")
      >= contextLength;
    message = ''
      hermes-agent needs services.ollama.environmentVariables.OLLAMA_CONTEXT_LENGTH
      set to at least ${toString contextLength} (currently ${
        config.services.ollama.environmentVariables.OLLAMA_CONTEXT_LENGTH or "unset"
      }).
    '';
  };

  networking.firewall.allowedTCPPorts = [
    apiPort
    dashboardPort
  ];
}
