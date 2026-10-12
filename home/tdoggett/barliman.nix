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

  # Hermes's model, taken from this machine's primaries in my-sd-models. See
  # the note at services.hermes-agent.settings.model for why it is the
  # "planning" role.
  hostName = osConfig.networking.hostName;
  hostPrimaryLLMs = pkgs.my-sd-models.machinePrimaryLLMs.${hostName} or { };
  hermesModel =
    hostPrimaryLLMs.planning
      or (throw "barliman.nix: ${hostName} has no 'planning' model in my-sd-models' machinePrimaryLLMs/${hostName}.nix");

  hermesHome = config.services.hermes-agent.hermesHome;

  # Hermes's config.yaml has two layers:
  #
  #  * services.hermes-agent.settings (below) is re-applied on every switch.
  #    Upstream's activation deep-merges it over the file on disk, so those
  #    keys always win and the dashboard cannot keep a change to them. Only
  #    plumbing that has to match the rest of this repo goes there: the Ollama
  #    endpoint, its context size, and the dashboard's Kanidm login.
  #
  #  * hermesDefaultConfig only fills in keys that config.yaml does not have
  #    yet, on every switch; any value already in the file (set from the
  #    dashboard, `hermes config set`, or by hand) is left alone. So a fresh
  #    ~/.hermes starts out with these, a key added here later reaches an
  #    existing install, and nothing set by hand gets reverted. A *changed*
  #    value here does not reach an existing install: e.g. a new "planning"
  #    model in my-sd-models has to be picked in the dashboard.
  hermesDefaultConfig = (pkgs.formats.json { }).generate "hermes-default-config.json" {
    model = {
      provider = "ollama-local";
      default = hermesModel;
    };

    # Dangerous-command approvals. `approvals.mode: off` is the config-file
    # spelling of YOLO mode, and stays available to turn on by hand. Defaults:
    # "manual" rather than upstream's "smart", because smart lets an auxiliary
    # LLM auto-approve commands it judges low-risk - one more model a hostile
    # page could talk into saying yes. The *_mode keys cover sessions with no
    # human to ask (API server/Conduit, cron, -q): refuse at once instead of
    # waiting out the timeout.
    approvals = {
      mode = "manual";
      unattended_mode = "deny";
      cron_mode = "deny";
      single_query_mode = "deny";
    };
  };

  # The reverse of upstream's configMergeScript: the file on disk wins, the
  # defaults only fill gaps. Like upstream's, it rewrites the file with
  # yaml.dump, so hand-written YAML comments do not survive a switch.
  hermesFillDefaults = pkgs.writeScript "hermes-fill-config-defaults" ''
    #!${pkgs.python3.withPackages (ps: [ ps.pyyaml ])}/bin/python3
    import json, sys, yaml
    from pathlib import Path

    defaults_path, config_path = sys.argv[1], Path(sys.argv[2])
    with open(defaults_path) as f:
        defaults = json.load(f)
    existing = {}
    if config_path.exists():
        with open(config_path) as f:
            existing = yaml.safe_load(f) or {}

    def fill_missing(on_disk, fallback):
        result = dict(on_disk)
        for key, value in fallback.items():
            if key not in result:
                result[key] = value
            elif isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = fill_missing(result[key], value)
        return result

    merged = fill_missing(existing, defaults)
    if merged != existing:
        config_path.parent.mkdir(parents=True, exist_ok=True)
        with open(config_path, "w") as f:
            yaml.dump(merged, f, default_flow_style=False, sort_keys=False)
        config_path.chmod(0o600)
  '';
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

  # The `hermes` CLI on PATH. Upstream's switch for it: it adds the same build
  # the services run (extraPythonPackages included) to home.packages and
  # exports HERMES_HOME, so `hermes config set ...` in a shell edits the
  # services' state. services.hermes-agent alone installs nothing on PATH.
  programs.hermes-agent.enable = true;

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
    # Model name comes from this machine's file in my-sd-models'
    # machinePrimaryLLMs/, keyed by hostname rather than spelled "barliman" so
    # a copy of this config on another host picks up that host's model. It
    # tracks the "planning" role: Hermes needs tools plus reasoning over them,
    # and that role's model also takes images, which the coding model does not,
    # so pictures sent from Conduit work. A thinking model is fine here because
    # Hermes talks to Ollama's /v1 endpoint, which folds thinking back into the
    # reply - the native API does not, which is what broke Karakeep.
    # Declare the endpoint as a named provider rather than leaning on the
    # inline `provider = "custom"` + base_url form. That inline form routes the
    # *default* model fine, but "custom" is not a declared provider, so picking
    # any other model in the dashboard failed with "Unknown provider 'custom'.
    # ... define it in config.yaml under 'providers:'". A real entry gives every
    # model on this endpoint a resolvable route, not just the startup default.
    # `discover_models` defaults to true, which is what populates the picker
    # from Ollama's live /v1/models list.
    settings.providers.ollama-local.api = ollamaUrl;

    # model.provider and model.default are only defaults (see hermesDefaultConfig),
    # so the dashboard's model picker sticks.
    settings.model = {
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

    # Approvals (YOLO on/off) are a default, not a pinned setting, so they can
    # be changed from the dashboard - see hermesDefaultConfig.

    # Gateway's OpenAI-style API, published by estel at <subdomains.hermes>.
    # Every client presents the same bearer API_SERVER_KEY; deliberately not
    # behind SSO because a login redirect would break Conduit.
    environment = {
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "0.0.0.0";
      API_SERVER_PORT = toString configVars.networking.ports.tcp.hermes;
      # HERMES_YOLO_MODE is deliberately NOT set (turned off 2026-10-12).
      # It disabled dangerous-command approval, so anyone holding the one
      # bearer key - or any web page or document whose text steered the model -
      # could run shell commands as tdoggett here, and reach feanor over SSH.
      #
      # Expected consequence: over the api_server path (Conduit) there is no
      # one to approve a command, so execute_code refuses shell calls, and the
      # model tends to narrate a plausible-sounding failure rather than say it
      # was refused. Hermes is meant to be the conversation and memory layer;
      # code changes belong to a separate, sandboxed worker.
    };
    environmentFiles = [ config.sops.templates."hermes-agent.env".path ];

    # The "worker" profile (PLAN.md, Phase 1): the coding agent. Unlike the
    # main config.yaml, this one is fully Nix-owned - reinstalled on every
    # switch - because its sandbox settings must not drift.
    #
    # Its tools run over SSH as agent-worker (hosts/common/optional/services/
    # agent-worker.nix), so YOLO mode is on *inside* that box: the limits are
    # that user's missing permissions and credentials, not approval prompts.
    #
    # Needs ~/.ssh/id_agent_worker (made by hand), whose public half goes in
    # hosts/common/users/<user>/agent-worker-keys/barliman.pub.
    hermesHomeFiles."profiles/worker/config.yaml" = (pkgs.formats.yaml { }).generate "hermes-worker-config.yaml" {
      providers.ollama-local.api = ollamaUrl;
      model = {
        provider = "ollama-local";
        # The worker-only variant with an output cap (hosts/barliman/default.nix)
        default = "_qwen3-coder-next-worker";
        context_length = lib.toInt (
          osConfig.services.ollama.environmentVariables.OLLAMA_CONTEXT_LENGTH or "65536"
        );
      };
      terminal = {
        backend = "ssh";
        ssh_host = "127.0.0.1";
        ssh_user = osConfig.services.agent-worker.user;
        ssh_key = "${config.home.homeDirectory}/.ssh/id_agent_worker";
        # Path on the worker's side; the clone is made there by hand.
        cwd = "${osConfig.services.agent-worker.home}/nix-config";
      };
      approvals.mode = "off";

      # Waiting for barliman's GPU is normal (my own chats, Karakeep, ...)
      # and must never quietly end a task. Hermes's default local ceiling is
      # 900 s with no first token; T1 (2026-10-12) hit it twice while I was
      # chatting. Raised to 12 h so that in the "waiting for a turn" case
      # Hermes never gives up first. The deadline that does fire, and alerts,
      # belongs to whatever runs the task (PLAN.md: a systemd unit with
      # RuntimeMaxSec=12h on the systemd-failure-alert list).
      agent.local_stream_stale_timeout = 43200;
    };

    hermesHomeFiles."profiles/worker/SOUL.md" = ''
      You are a coding worker for a NixOS flake repository. If the repository
      has an AGENTS.md at its root, read it before changing anything and
      follow its conventions. (Hermes's automatic context-file discovery looks
      in its own working directory, which is not the repository: your tools
      run over SSH in a different place, so read it yourself.)

      Hard rules:
      - Edit files and `git add` them. Never `git commit`, `git push`, or
        rewrite history; a human reviews the staged diff and commits.
      - Never create, edit or decrypt secrets. If a change needs one, name the
        sops key and any constraints on its value in your report.
      - Only run `nixos-rebuild` against the test targets you were given.
      - Report honestly. If a command failed or was refused, say so and quote
        the error; never describe output you did not see.

      Finish with a report: what you changed (files), what you ran and its
      result (builds, tests), errors you hit and how you fixed them, and what
      you still need from the human.
    '';
  };

  # The worker profile's SSH connection to agent-worker. Without this, ssh also
  # offers every key in the agent first (logged as "Failed publickey" for
  # personal_ed25519 on each tool call), and the core config's "*" block asks
  # to forward the agent - which only the key's no-agent-forwarding option on
  # the server side was refusing. `user` in Match is the remote user.
  programs.ssh.settings."agent-worker" = {
    header = "Match host 127.0.0.1,::1 user ${osConfig.services.agent-worker.user}";
    IdentityFile = "${config.home.homeDirectory}/.ssh/id_agent_worker";
    IdentitiesOnly = true;
    IdentityAgent = "none";
    ForwardAgent = false;
  };

  # Turn off upstream's "managed mode". The module tags the install as owned
  # by home-manager twice: HERMES_MANAGED=home-manager in both units, and a
  # ~/.hermes/.managed marker for interactive shells. Either one makes Hermes
  # refuse every config.yaml and .env write - and the dashboard's version of
  # that refusal is silent: save_config() prints to stderr and returns, so the
  # UI reports success while nothing is saved. "false" is upstream's explicit
  # opt-out value (HERMES_MANAGED=false). systemd uses the last assignment of
  # a repeated variable, hence mkAfter.
  systemd.user.services.hermes-agent.Service.Environment = lib.mkAfter [ "HERMES_MANAGED=false" ];
  systemd.user.services.hermes-backend.Service.Environment = lib.mkAfter [ "HERMES_MANAGED=false" ];

  home.activation = {
    # Before upstream's hermesAgentSetup, so its pinned `settings` still land
    # on top of these defaults.
    hermesAgentFillDefaults = lib.hm.dag.entryBetween [ "hermesAgentSetup" ] [ "writeBoundary" ] ''
      run ${hermesFillDefaults} ${hermesDefaultConfig} ${lib.escapeShellArg "${hermesHome}/config.yaml"}
    '';

    # hermesAgentSetup rewrites .managed as "home-manager" on every switch;
    # overwrite it afterwards so the `hermes` CLI in a shell is unlocked too.
    hermesAgentUnmanage = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
      run install -m 0600 ${pkgs.writeText "hermes-unmanaged" "false"} ${lib.escapeShellArg "${hermesHome}/.managed"}
    '';
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
