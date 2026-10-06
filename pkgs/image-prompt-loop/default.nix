{ writers }:

# Self-correcting image generation: render a prompt on ComfyUI or InvokeAI,
# have an Ollama vision model critique the result and rewrite the prompt,
# repeat. Also turns an image into a prompt ("describe"). Standard library only.
writers.writePython3Bin "image-prompt-loop" {
  # E501: long prompt strings read better unwrapped
  flakeIgnore = [ "E501" ];
} (builtins.readFile ./image_prompt_loop.py)
