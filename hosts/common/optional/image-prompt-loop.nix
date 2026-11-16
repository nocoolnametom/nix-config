{
  config,
  lib,
  pkgs,
  configVars,
  ...
}:
let
  cfg = config.programs.image-prompt-loop;
  smeagolLan = "smeagol.${configVars.homeLanDomain}";
in
{
  # image-prompt-loop (pkgs/image-prompt-loop): renders on ComfyUI/InvokeAI,
  # critiques with an Ollama vision model, rewrites the prompt and repeats.
  # These options only set the defaults; every one can be overridden per run
  # with a command-line flag.
  options.programs.image-prompt-loop = {
    ollamaUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:${toString configVars.networking.ports.tcp.lemonade}";
      description = "Lemonade-compatible server running the caption and critic models.";
    };
    comfyuiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${smeagolLan}:${toString configVars.networking.ports.tcp.comfyui}";
      description = "ComfyUI server used by `refine --backend comfyui`.";
    };
    invokeaiUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${smeagolLan}:${toString configVars.networking.ports.tcp.invokeai}";
      description = "InvokeAI server used by `refine --backend invokeai`.";
    };
    # No defaults: the host names these from its my-sd-models primary roles
    # (caption/critic in machinePrimaryLLMs/<host>.nix), so the names live in one place.
    captionModel = lib.mkOption {
      type = lib.types.str;
      description = "Lemonade model that writes the first prompt from a reference image.";
    };
    criticModel = lib.mkOption {
      type = lib.types.str;
      description = "Lemonade vision model that reviews each image and rewrites the prompt.";
    };
  };

  config = {
    sops.secrets."homelab/lemonade/api-key" = {
      owner = configVars.username;
      mode = "0400";
    };
    environment.systemPackages = [ pkgs.image-prompt-loop ];
    environment.variables = {
      IMAGE_PROMPT_LOOP_OLLAMA_URL = cfg.ollamaUrl;
      IMAGE_PROMPT_LOOP_API_KEY_FILE = config.sops.secrets."homelab/lemonade/api-key".path;
      IMAGE_PROMPT_LOOP_COMFYUI_URL = cfg.comfyuiUrl;
      IMAGE_PROMPT_LOOP_INVOKEAI_URL = cfg.invokeaiUrl;
      IMAGE_PROMPT_LOOP_CAPTION_MODEL = cfg.captionModel;
      IMAGE_PROMPT_LOOP_CRITIC_MODEL = cfg.criticModel;
    };
  };
}
