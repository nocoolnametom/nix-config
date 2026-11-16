{
  lib,
  pkgs,
  config,
  configVars,
  ...
}:
let
  ssoProvider = config.services.ssoProvider.openwebui or "authentik";
  useKanidm = ssoProvider == "kanidm-oidc";
  lemonadeCatalogs = pkgs.my-sd-models.machineLemonadeModels or { };
  lemonadeCatalog = lib.attrByPath [ config.networking.hostName ] { } lemonadeCatalogs;
  lemonadeDefaults =
    if builtins.isAttrs lemonadeCatalog then
      lemonadeCatalog.defaults
        or (throw "Open WebUI requires named defaults in machineLemonadeModels/${config.networking.hostName}")
    else
      throw "Open WebUI requires a structured machineLemonadeModels/${config.networking.hostName} catalog";
  ttsDefaults = lemonadeDefaults.tts;
  sttDefaults = lemonadeDefaults.stt;
  taskDefaults = lemonadeDefaults.task;
  realtimeDefaults = lemonadeDefaults.realtime;
  managedConfigKeys = [
    "webui.url"
    "ui.enable_signup"
    "ui.default_user_role"
    "web.search.enable"
    "web.search.engine"
    "web.search.result_count"
    "web.search.concurrent_requests"
    "web.search.trust_env"
    "web.loader.concurrent_requests"
    "openai.enable"
    "openai.api_base_urls"
    "openai.api_keys"
    "openai.api_configs"
    "ollama.enable"
    "task.model.default"
    "task.model.external"
    "subagents.enable"
    "subagents.background_enabled"
    "audio.stt.engine"
    "audio.stt.openai.api_base_url"
    "audio.stt.openai.api_key"
    "audio.tts.engine"
    "audio.tts.model"
    "audio.tts.voice"
    "audio.tts.openai.api_base_url"
    "audio.tts.openai.api_key"
    "audio.realtime.enabled"
    "audio.realtime.auth_type"
    "audio.realtime.model"
    "audio.realtime.transcription_model"
    "audio.realtime.openai.api_base_url"
    "audio.realtime.openai.api_key"
    "audio.realtime.voice"
  ]
  ++ lib.optionals (config.services.obscuraWebLoader.enable or false) [
    "web.loader.engine"
    "web.loader.external_web_loader_url"
    "web.loader.external_web_loader_api_key"
  ];
  managedConfigKeysSql = lib.concatMapStringsSep ", " (key: "'${key}'") managedConfigKeys;
  lemonadeApiBase = "http://127.0.0.1:${toString configVars.networking.ports.tcp.lemonade}/api/v1";
in
{
  services.open-webui.enable = lib.mkDefault true;
  services.open-webui.host = lib.mkDefault "0.0.0.0";
  services.open-webui.port = lib.mkDefault configVars.networking.ports.tcp.openwebui;
  services.open-webui.openFirewall = lib.mkDefault true;
  # Where Open WebUI sends the browser after login (and builds links from).
  # The nixpkgs module defaults it to http://localhost:<port>.
  services.open-webui.environment = {
    WEBUI_URL = "https://${configVars.networking.subdomains.openwebui}.${configVars.homeDomain}";
    ENABLE_SIGNUP = "false";
    DEFAULT_USER_ROLE = "user";
    ENABLE_WEB_SEARCH = "true";
    WEB_SEARCH_ENGINE = "kagi";
    WEB_SEARCH_RESULT_COUNT = "3";
    WEB_SEARCH_CONCURRENT_REQUESTS = "10";
    WEB_SEARCH_TRUST_ENV = "false";
    WEB_LOADER_CONCURRENT_REQUESTS = "10";
    OPENAI_API_BASE_URLS = lemonadeApiBase;
    OPENAI_API_CONFIGS = builtins.toJSON {
      "0" = {
        enable = true;
        tags = [ ];
        prefix_id = "";
        model_ids = [ ];
        connection_type = "external";
        auth_type = "bearer";
        forward_cookies = false;
        passthrough_params = [ ];
      };
    };
    ENABLE_OPENAI_API = "true";
    ENABLE_OLLAMA_API = "false";
    TASK_MODEL = taskDefaults.model;
    TASK_MODEL_EXTERNAL = taskDefaults.externalModel;
    ENABLE_SUBAGENTS = "true";
    SUBAGENTS_BACKGROUND_ENABLED = "true";
    AUDIO_STT_ENGINE = "";
    AUDIO_STT_MODEL = sttDefaults.model;
    AUDIO_STT_OPENAI_API_BASE_URL = "${lemonadeApiBase}";
    AUDIO_TTS_ENGINE = "openai";
    AUDIO_TTS_MODEL = ttsDefaults.model;
    AUDIO_TTS_VOICE = ttsDefaults.voice;
    AUDIO_TTS_OPENAI_API_BASE_URL = "${lemonadeApiBase}";
    AUDIO_REALTIME_ENABLED = "false";
    AUDIO_REALTIME_AUTH_TYPE = "api_key";
    AUDIO_REALTIME_PROVIDER = "openai";
    AUDIO_REALTIME_MODEL = realtimeDefaults.model;
    AUDIO_REALTIME_TRANSCRIPTION_MODEL = realtimeDefaults.transcriptionModel;
    AUDIO_REALTIME_VOICE = realtimeDefaults.voice;
    AUDIO_REALTIME_OPENAI_API_BASE_URL = "${lemonadeApiBase}";
  };

  # Authentik OIDC secrets
  sops.secrets."open-webui-slug" = { };
  sops.secrets."open-webui-clientid" = { };
  sops.secrets."open-webui-clientsecret" = { };

  # Kanidm OIDC secrets
  sops.secrets."homelab/kanidm/oidc/openwebui/client-secret" = { };
  sops.secrets."homelab/lemonade/api-key" = { };
  sops.templates."open-webui.conf".content =
    (
      if useKanidm then
        ''
          ENABLE_OAUTH_SIGNUP=true
          OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
          OAUTH_PROVIDER_NAME=Kanidm
          OPENID_PROVIDER_URL=https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/openwebui/.well-known/openid-configuration
          OAUTH_CLIENT_ID=openwebui
          OAUTH_CLIENT_SECRET=${config.sops.placeholder."homelab/kanidm/oidc/openwebui/client-secret"}
          OAUTH_SCOPES=openid email profile
          OPENID_REDIRECT_URI=https://${configVars.networking.subdomains.openwebui}.${configVars.domain}/oauth/oidc/callback
          # Kanidm requires PKCE.
          OAUTH_CODE_CHALLENGE_METHOD=S256
        ''
      else
        ''
          ENABLE_OAUTH_SIGNUP=true
          OAUTH_MERGE_ACCOUNTS_BY_EMAIL=true
          OAUTH_PROVIDER_NAME=Authentik
          OPENID_PROVIDER_URL=https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/${
            config.sops.placeholder."open-webui-slug"
          }/.well-known/openid-configuration
          OAUTH_CLIENT_ID=${config.sops.placeholder."open-webui-clientid"}
          OAUTH_CLIENT_SECRET=${config.sops.placeholder."open-webui-clientsecret"}
          OAUTH_SCOPES=openid email profile
          OPENID_REDIRECT_URI=https://${configVars.networking.subdomains.openwebui}.${configVars.domain}/oauth/oidc/callback
        ''
    )
    + ''
      OPENAI_API_KEYS=${config.sops.placeholder."homelab/lemonade/api-key"}
      AUDIO_STT_OPENAI_API_KEY=${config.sops.placeholder."homelab/lemonade/api-key"}
      AUDIO_TTS_OPENAI_API_KEY=${config.sops.placeholder."homelab/lemonade/api-key"}
      AUDIO_REALTIME_OPENAI_API_KEY=${config.sops.placeholder."homelab/lemonade/api-key"}
    '';
  # Open WebUI reads this file only at start, so a changed secret must restart it.
  sops.templates."open-webui.conf".restartUnits = [ "open-webui.service" ];
  services.open-webui.environmentFile = lib.mkDefault config.sops.templates."open-webui.conf".path;

  systemd.services.open-webui.preStart = lib.mkAfter ''
    database="${config.services.open-webui.stateDir}/data/webui.db"
    if [ -f "$database" ]; then
      ${pkgs.sqlite}/bin/sqlite3 "$database" <<'SQL'
    DELETE FROM config WHERE key IN (${managedConfigKeysSql});
    SQL
    fi
  '';
}
