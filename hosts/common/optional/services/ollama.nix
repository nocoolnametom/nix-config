{
  pkgs,
  lib,
  config,
  ...
}:
{
  services.ollama.enable = lib.mkDefault true;
  services.ollama.host = "0.0.0.0";
  services.ollama.port = 11434;
  services.ollama.openFirewall = lib.mkDefault true;
  services.ollama.package = lib.mkDefault pkgs.ollama-cuda;
  services.ollama.loadModels = lib.mkDefault (
    lib.attrByPath [ config.networking.hostName ] [ ] pkgs.my-sd-models.machineLLMs
  );
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
  # Hermes (hermes-agent.nix) requires at least 64K.
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
}
