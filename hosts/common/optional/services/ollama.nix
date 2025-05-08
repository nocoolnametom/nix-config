{ pkgs, lib, ... }:
{
  environment.systemPackages = [
    pkgs.unstable.ollama
  ];
  services.ollama.enable = lib.mkDefault true;
  services.ollama.host = "0.0.0.0";
  services.ollama.port = 11434;
  services.ollama.package = pkgs.unstable.ollama;
  services.ollama.loadModels = [
    # Models higher than 9GB will use CPU with GPU, less will be entirely on GPU
    # You CAN get a model up to ~40GB, but it'll mostly be CPU driven and slow.
    # YC = Can talk about Chinese censored info, NC = Chinese info blocked
    # YA = Can talk about upsetting info, NA = Will refuse talk about it
    #  4.9 GB  2025-02-19  YC  YA - Very talkative
    "huihui_ai/deephermes3-abliterated"
    #  1.5 GB  2025-02-14  NC  NA - Usually refuses, sometimes ignores the upsetting aspects
    "huihui_ai/deepscaler-abliterated"
    #  4.9 GB  2025-01-25  NC  YA - Semi-talktative, talks around upsetting subjects
    "huihui_ai/deepseek-r1-abliterated"
    #  4.9 GB  2025-01-08  YC  YA - Talkative
    "huihui_ai/dolphin3-abliterated"
    #  9.1 GB  2025-01-09  YC  YA - Semi-talkative, talks around and ignores upsetting stuff
    "huihui_ai/phi4-abliterated" # Requires ollama 0.5.5+, which is why we're using unstable
    #  4.7 GB  2025-01-28  YC  YA - Usually refuses, sometimes is talkative
    "huihui_ai/qwen2.5-1m-abliterated"
    #  8.6 GB  2024-05-01  YC  YA - Semi-talkative, often ignores upsetting aspects
    "superdrew100/phi3-medium-abliterated"
    #  4.9 GB  2025-01-21  NC  NA
    "deepseek-r1"
    #  4.9 GB  2024-12-29  YC  YA - Semi-talkative
    "dolphin3"
    #  4.7 GB  2024-05-20  YC  YA - Talkative
    "dolphin-llama3"
    #  4.1 GB  2024-03-01  YC  YA - Talkative
    "dolphin-mistral"
    #  5.0 GB  2025-01-18  YC  YA - Talkative
    "granite3.1-dense"
    #  4.9 GB  2024-11-01  YC  NA
    "llama3.1"
    #  2.0 GB  2024-09-01  YC  NA
    "llama3.2"
    #  7.1 GB  2024-07-18  YC  YA - Very talkative
    "mistral-nemo"
    # 13.0 GB  2024-09-01  YC  NA
    "mistral-small"
  ];
  services.ollama.acceleration = "cuda";
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
