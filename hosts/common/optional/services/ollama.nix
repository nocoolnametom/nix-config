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
  # Without this Ollama picks the context size from GPU memory: 256k (capped at
  # each model's maximum) once it sees 47+ GiB. That reserves a huge KV cache
  # (~11 GiB for a 24B model at 128k) that ordinary chats never use.
  services.ollama.environmentVariables.OLLAMA_CONTEXT_LENGTH = lib.mkDefault "32768";
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
