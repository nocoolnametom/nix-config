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
  services.ollama.package = lib.mkDefault pkgs.unstable.ollama-cuda;
  services.ollama.loadModels = lib.mkDefault (
    lib.attrByPath [ config.networking.hostName ] [ ] pkgs.my-sd-models.machineLLMs
  );
  services.ollama.environmentVariables.OLLAMA_KEEP_ALIVE = "900";
  services.ollama.environmentVariables.OLLAMA_LLAMA_GPU_LAYERS = "100";
  # The existing systemd job is SO tightened down that it can't read the WSL drivers AT ALL
  systemd.services.ollama.serviceConfig = lib.mkForce {
    Type = "exec";
    ExecStart = "${pkgs.unstable.ollama}/bin/ollama serve";
    WorkingDirectory = "/var/lib/ollama";
  };
  systemd.tmpfiles.rules = [
    "d '/var/lib/ollama' 0777 root root - -"
  ];
}
