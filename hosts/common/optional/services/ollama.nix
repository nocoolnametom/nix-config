{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.ollama;
  ollamaExe = lib.getExe cfg.package;

  # my-sd-models' machineLLMs/<host>.nix: { "<intendedName>" = "<actualName>"; }.
  # Older revisions of it were a plain list of names; accept that too, so this
  # repo and my-sd-models don't have to change in lockstep.
  hostLLMs = lib.attrByPath [ config.networking.hostName ] { } pkgs.my-sd-models.machineLLMs;
  hostModelsByName =
    if builtins.isList hostLLMs then lib.genAttrs hostLLMs (name: name) else hostLLMs;

  # Entries whose name in the tools differs from what Ollama downloads
  aliases = lib.filterAttrs (intendedName: actualName: intendedName != actualName) cfg.namedModels;
  # Downloaded names to remove after copying, so tools only see the intended
  # name. One that is also wanted under its own name stays.
  namesToHide = lib.subtractLists (lib.attrNames cfg.namedModels) (
    lib.unique (lib.attrValues aliases)
  );
in
{
  options.services.ollama.namedModels = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = hostModelsByName;
    example = {
      "qwen3-coder" = "qwen3-coder";
      "_qwen3.5:35b" = "huihui_ai/qwen3.5-abliterated:35b";
    };
    description = ''
      Models to download, as { "<intendedName>" = "<actualName>"; }. Ollama pulls
      each actualName; when intendedName differs, the model is copied to it
      (`ollama cp`, which shares the files rather than duplicating them) and the
      actualName is removed, so tools only ever see intendedName. Prefix such
      names with "_" so they can't collide with a real library model.
      Defaults to this host's file in my-sd-models' machineLLMs/.
    '';
  };

  config = {
    services.ollama.enable = lib.mkDefault true;
    services.ollama.host = "0.0.0.0";
    services.ollama.port = 11434;
    services.ollama.openFirewall = lib.mkDefault true;
    services.ollama.package = lib.mkDefault pkgs.ollama-cuda;
    services.ollama.loadModels = lib.mkDefault (lib.unique (lib.attrValues cfg.namedModels));

    # syncModels deletes every installed model not in loadModels, which would
    # include each copied (intended) name right after it is made
    assertions = [
      {
        assertion = aliases == { } || !cfg.syncModels;
        message = "services.ollama.syncModels would delete the renamed models from services.ollama.namedModels (${lib.concatStringsSep ", " (lib.attrNames aliases)}); leave it off.";
      }
    ];

    # Upstream's ollama-model-loader pulls loadModels in the background
    # (Type=exec), so the copies are made when it exits: ExecStopPost runs only
    # after every pull has finished. If a pull failed, the loader restarts and
    # this runs again after the retry.
    systemd.services.ollama-model-loader.postStop = lib.mkIf (aliases != { }) ''
      if [ "$SERVICE_RESULT" != success ]; then
        echo "Model loader ended with '$SERVICE_RESULT'; renaming models after it succeeds"
        exit 0
      fi
      ${lib.concatStrings (
        lib.mapAttrsToList (intendedName: actualName: ''
          if ${ollamaExe} show ${lib.escapeShellArg actualName} >/dev/null 2>&1; then
            ${ollamaExe} cp ${lib.escapeShellArg actualName} ${lib.escapeShellArg intendedName} \
              || echo "Warning: could not copy ${actualName} to ${intendedName}"
          elif ! ${ollamaExe} show ${lib.escapeShellArg intendedName} >/dev/null 2>&1; then
            echo "Warning: neither ${actualName} nor ${intendedName} is installed"
          fi
        '') aliases
      )}
      ${lib.concatMapStrings (actualName: ''
        if ${ollamaExe} show ${lib.escapeShellArg actualName} >/dev/null 2>&1; then
          ${ollamaExe} rm ${lib.escapeShellArg actualName} \
            || echo "Warning: could not remove ${actualName}"
        fi
      '') namesToHide}
    '';
    # How long an idle model stays loaded. Reloading costs several seconds plus
    # re-reading the whole chat history, so keep it well past a coffee break.
    services.ollama.environmentVariables.OLLAMA_KEEP_ALIVE = lib.mkDefault "1h";
    # Context window each model gets unless a client asks for a different size.
    # Ollama clamps it to each model's own maximum. Left unset, Ollama picks it
    # from GPU memory (under 24 GiB: 4K, under 48 GiB: 32K, else 256K), and it
    # counts GPU memory after OLLAMA_GPU_OVERHEAD, so barliman would only get 32K.
    #
    # 192K was measured on barliman (2026-10-08, q8_0 cache, OLLAMA_NUM_PARALLEL=2).
    # The largest models need about 40 GiB at this size (mistral-nemo,
    # dans-personalityengine), out of the ~49 GiB Ollama can use there. At 256K,
    # mistral-nemo needs 50.7 GiB, more than fits. Real use stayed within ~1.3 GiB
    # of what Ollama reserves at load time. Reading an uncached prompt runs at
    # about 300 tokens/s, so a full 192K prompt takes 10+ minutes on first read.
    # Hermes (hermes-agent.nix) requires at least 64K. Karakeep (karakeep.nix)
    # repeats this number as INFERENCE_CONTEXT_LENGTH; change both together.
    services.ollama.environmentVariables.OLLAMA_CONTEXT_LENGTH = lib.mkDefault "196608";
    # Flash attention is required for a quantized KV cache. q8_0 roughly halves
    # the memory each token of context costs versus the f16 default, with
    # negligible quality loss, so longer contexts (or bigger models) fit.
    services.ollama.environmentVariables.OLLAMA_FLASH_ATTENTION = lib.mkDefault "1";
    services.ollama.environmentVariables.OLLAMA_KV_CACHE_TYPE = lib.mkDefault "q8_0";
    # The upstream unit's sandboxing originally blocked access to the WSL GPU
    # drivers, so it's replaced wholesale. That also discards any other
    # serviceConfig a host sets, so ExecStart must honor services.ollama.package
    # itself rather than hardcoding pkgs.ollama.
    systemd.services.ollama.serviceConfig = lib.mkForce {
      Type = "exec";
      ExecStart = "${config.services.ollama.package}/bin/ollama serve";
      WorkingDirectory = "/var/lib/ollama";
    };
    systemd.tmpfiles.rules = [
      "d '/var/lib/ollama' 0777 root root - -"
    ];
  };
}
