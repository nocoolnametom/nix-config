{
  config,
  lib,
  pkgs,
  ...
}:
{
  # llama.cpp command-line tools: llama-server (OpenAI-compatible API),
  # llama-cli, llama-bench, llama-quantize, ...
  # Having them in PATH also lets tools like llmfit detect llama.cpp and launch
  # GGUF models with it.
  #
  # Default build is Vulkan-only. Vulkan runs on any modern GPU, and on AMD
  # APUs it often generates tokens faster than ROCm. ROCm is still faster at
  # prompt processing, so a host that already runs Ollama on ROCm can compare
  # the two backends with llama-bench against the same GGUF file.
  # rocmSupport is forced off because nixpkgs.config.rocmSupport = true would
  # otherwise also compile HIP into this build.
  options.programs.llama-cpp.package = lib.mkOption {
    type = lib.types.package;
    default = pkgs.llama-cpp.override {
      vulkanSupport = true;
      rocmSupport = false;
      cudaSupport = false;
    };
    defaultText = lib.literalExpression "pkgs.llama-cpp.override { vulkanSupport = true; rocmSupport = false; cudaSupport = false; }";
    description = "llama.cpp build to install system-wide.";
  };

  config.environment.systemPackages = [ config.programs.llama-cpp.package ];
}
