{
  lib,
  pkgs,
  configVars,
  config,
  ...
}:
let
  # Karakeep tags and summarises both text and images, so it needs a model that
  # accepts image input; barliman's "visual" role is exactly that. Taking it from
  # my-sd-models rather than hardcoding a name also gets eval-time validation
  # that the model is actually installed there (machinePrimaryLLMs in its flake).
  visualModel = pkgs.my-sd-models.machinePrimaryLLMs.barliman.visual;

  # Semantic search. Karakeep compares every returned vector against
  # EMBEDDING_DIMENSIONS and throws on a mismatch, so the width below is part of
  # the model choice rather than a tuneable: qwen3-embedding:0.6b emits 1024.
  embeddingModel = pkgs.my-sd-models.machinePrimaryLLMs.barliman.embedding;
  embeddingDimensions = 1024;
  # How much of a bookmark is folded into its one vector. The model accepts
  # 32768 tokens, so this is a judgement call rather than a limit: the whole
  # excerpt becomes a single point in vector space, and stretching it over a
  # book's worth of text makes that point describe nothing in particular.
  # Karakeep's own default is the sane middle, and unlike with the 2024-era
  # embedders it is now reachable without being truncated away.
  embeddingContextLength = 8000;

  ssoProvider = config.services.ssoProvider.karakeep or "authentik";
  useKanidm = ssoProvider == "kanidm-oidc";
  wellknownURL =
    if useKanidm then
      "https://${configVars.networking.subdomains.kanidm}.${configVars.homeDomain}/oauth2/openid/karakeep/.well-known/openid-configuration"
    else
      "https://${configVars.networking.subdomains.authentik}.${configVars.homeDomain}/application/o/karakeep/.well-known/openid-configuration";
in
{
  sops.secrets."homelab/smtp/host" = { };
  sops.secrets."homelab/smtp/port" = { };
  sops.secrets."homelab/smtp/username" = { };
  sops.secrets."homelab/smtp/password" = { };
  sops.secrets."homelab/smtp/sendingDomain" = { };
  sops.secrets."homelab/smtp/ssl" = { };

  # Authentik OIDC secrets
  sops.secrets."homelab/oidc/karakeep/authentik/client-id" = { };
  sops.secrets."homelab/oidc/karakeep/authentik/client-secret" = { };

  # Kanidm OIDC secrets
  sops.secrets."homelab/kanidm/oidc/karakeep/client-secret" = { };
  sops.templates."karakeep-secrets.env" = {
    content = ''
      SMTP_HOST=${config.sops.placeholder."homelab/smtp/host"}
      SMTP_PORT=${config.sops.placeholder."homelab/smtp/port"}
      SMTP_SECURE=${config.sops.placeholder."homelab/smtp/ssl"}
      SMTP_USER=${config.sops.placeholder."homelab/smtp/username"}
      SMTP_PASSWORD=${config.sops.placeholder."homelab/smtp/password"}
      SMTP_FROM=no-reply+karakeep@${config.sops.placeholder."homelab/smtp/sendingDomain"}
    ''
    + (
      if useKanidm then
        ''
          OAUTH_CLIENT_ID=karakeep
          OAUTH_CLIENT_SECRET=${config.sops.placeholder."homelab/kanidm/oidc/karakeep/client-secret"}
        ''
      else
        ''
          OAUTH_CLIENT_ID=${config.sops.placeholder."homelab/oidc/karakeep/authentik/client-id"}
          OAUTH_CLIENT_SECRET=${config.sops.placeholder."homelab/oidc/karakeep/authentik/client-secret"}
        ''
    );
    owner = if config.services.karakeep.enable then "karakeep" else "root";
    # Services read this file only at start, so a changed secret must restart them.
    restartUnits = [
      "karakeep-web.service"
      "karakeep-workers.service"
    ];
  };
  services.karakeep.enable = lib.mkDefault true;
  services.karakeep.browser.enable = lib.mkDefault true;
  services.karakeep.meilisearch.enable = lib.mkDefault true;
  services.karakeep.environmentFile = lib.mkDefault config.sops.templates."karakeep-secrets.env".path;
  services.karakeep.extraEnvironment.PORT = builtins.toString configVars.networking.ports.tcp.karakeep;
  services.karakeep.extraEnvironment.DISABLE_PASSWORD_AUTH = "true";
  services.karakeep.extraEnvironment.DISABLE_NEW_RELEASE_CHECK = "true";
  services.karakeep.extraEnvironment.NEXTAUTH_URL = "https://${configVars.networking.subdomains.karakeep}.${configVars.homeDomain}";
  services.karakeep.extraEnvironment.OAUTH_WELLKNOWN_URL = wellknownURL;
  services.karakeep.extraEnvironment.OAUTH_PROVIDER_NAME =
    if useKanidm then "Kanidm" else "authentik";
  # Lets an OIDC login attach to the existing account with the same email,
  # which is how accounts survive a change of identity provider.
  services.karakeep.extraEnvironment.OAUTH_ALLOW_DANGEROUS_EMAIL_ACCOUNT_LINKING = "true";
  # AI tagging and summaries run on barliman's Ollama (smeagol stopped running
  # Ollama in 2026-08).
  #
  # Both model slots get barliman's visual primary. It must NOT be a thinking
  # model: Karakeep calls Ollama's native /api/generate with `format` set to a
  # JSON schema and never sends `think: false`, and under that grammar a
  # thinking model puts its whole answer in the separate `thinking` field,
  # leaving `response` empty. Karakeep reads only `response`, so every job dies
  # with "The model ignored our prompt and didn't respond with the expected
  # JSON" and a blank excerpt. This is why "_qwen3.5" was wrong here despite
  # being vision-capable, and why Hermes is unaffected by the same model: it
  # talks to /v1, where Ollama folds thinking back into content.
  services.karakeep.extraEnvironment.OLLAMA_BASE_URL = "http://${configVars.networking.subnets.barliman.ip}:${builtins.toString configVars.networking.ports.tcp.ollama}";
  services.karakeep.extraEnvironment.INFERENCE_TEXT_MODEL = visualModel;
  services.karakeep.extraEnvironment.INFERENCE_IMAGE_MODEL = visualModel;
  # Karakeep sends this as Ollama's num_ctx. It no longer has to match
  # barliman's OLLAMA_CONTEXT_LENGTH: that rule existed when this shared
  # Hermes's model, where a differing num_ctx forced a reload and threw away
  # Hermes's cached conversation. The visual model is Karakeep's alone, so it
  # simply loads once at whatever size is asked for here.
  #
  # It is a cap on real work, though: Karakeep tokenises the page and keeps
  # only (this - prompt) tokens, so anything longer is dropped before the model
  # sees it. 64K leaves room for roughly 49,000 words, far past any ordinary
  # article; an image costs about 1,000 tokens, so pictures are not a factor.
  #
  # The ceiling is memory. Measured on barliman 2026-10-11, this model resident:
  # 20.6 GB at 32K, 22.3 GB at 64K, 29.5 GB at 192K. Hermes keeps its own model
  # loaded next to it (hermes-agent.nix, _qwen3.8, 18 GB at 192K), and the pair
  # has to fit: 64K leaves about 9 GB spare, while 192K makes Ollama evict one
  # to load the other. Raising this means re-checking that sum - and note it
  # scales with whatever Hermes's "planning" model costs, not just this one.
  services.karakeep.extraEnvironment.INFERENCE_CONTEXT_LENGTH = "65536";
  # No OLLAMA_KEEP_ALIVE: each request resets the model's idle timer to the
  # value it sends, so a short one here would unload the model early.
  services.karakeep.extraEnvironment.INFERENCE_ENABLE_AUTO_SUMMARIZATION = "true";

  # Embeddings, which back semantic search (SEMANTIC_SEARCH_ENABLED is already
  # true by default). All four of these have to be set together:
  #
  #   * EMBEDDING_TEXT_MODEL otherwise defaults to OpenAI's name
  #     "text-embedding-3-small", which Karakeep then asks *Ollama* for, and
  #     every job fails with 'model not found, try pulling it first'.
  #   * EMBEDDING_DIMENSIONS otherwise defaults to 1536 (that OpenAI model's
  #     width) and Karakeep rejects nomic's 768-wide vectors outright.
  #   * EMBEDDING_ENABLE_AUTO_INDEXING, left unset, resolves to
  #     "!OLLAMA_BASE_URL && !OPENAI_BASE_URL && !!OPENAI_API_KEY" - which is
  #     false precisely because OLLAMA_BASE_URL is set. Ollama users have to
  #     opt in explicitly or nothing is ever indexed.
  #   * EMBEDDING_CONTEXT_LENGTH: see embeddingContextLength above.
  #
  # Changing the model later means changing the width to match and reindexing,
  # since stored vectors of the old width are not comparable.
  services.karakeep.extraEnvironment.EMBEDDING_TEXT_MODEL = embeddingModel;
  services.karakeep.extraEnvironment.EMBEDDING_DIMENSIONS = builtins.toString embeddingDimensions;
  services.karakeep.extraEnvironment.EMBEDDING_CONTEXT_LENGTH = builtins.toString embeddingContextLength;
  services.karakeep.extraEnvironment.EMBEDDING_ENABLE_AUTO_INDEXING = "true";
}
