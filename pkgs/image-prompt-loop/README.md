# image-prompt-loop

Local, self-correcting image generation. It renders a prompt on ComfyUI or
InvokeAI, shows the result to a vision model running in Ollama, and lets that
model list what's wrong and rewrite the prompt. Then it renders again.

It uses two Ollama models:

- a critic that reviews images and rewrites prompts: Qwen3-VL 30B-A3B Instruct
  (`--critic-model`, default `qwen3-vl:30b-a3b-instruct`)
- a captioner that turns an image into a prompt: JoyCaption Beta One
  (`--caption-model`, default `aha2025/llama-joycaption-beta-one-hf-llava:Q6_K`)

barliman downloads them through `my-sd-models/machineLLMs/barliman.nix`, which
can list them under other names (e.g. `_qwen3-vl`). Those names, and the server
URLs, are set in `hosts/common/optional/image-prompt-loop.nix` (the
`programs.image-prompt-loop.*` options), which passes them on through
`IMAGE_PROMPT_LOOP_*` environment variables. Command-line flags override them.

## Image to prompt

```bash
image-prompt-loop describe photo.png                  # Stable Diffusion-style prompt
image-prompt-loop describe --style booru photo.png    # booru tag list
```

Styles: `sd`, `booru`, `descriptive`, `straightforward`.

## Refine a prompt

### ComfyUI

1. Build the workflow in ComfyUI. In the positive prompt node, type exactly
   `%PROMPT%`. Optionally type `%NEGATIVE%` in the negative prompt.
2. Choose **Workflow → Export (API)**. The normal "Save" format won't work.
3. If you want, set the seed widget's value to `"%SEED%"` in the exported JSON.
   Without it, every `seed`/`noise_seed` input is overwritten.

`examples/comfyui-sdxl-api.json` is a minimal SDXL workflow. Set its
`ckpt_name` before using it.

```bash
image-prompt-loop refine --backend comfyui --template my-workflow-api.json \
  --prompt "a red fox sitting in fresh snow, morning light, photograph" --rounds 5
```

### InvokeAI

Generate one image in InvokeAI with the model and settings you want. Then reuse
its graph by giving the image's name (shown in the image's info panel, e.g.
`d69c538a-....png`):

```bash
image-prompt-loop refine --backend invokeai --from-image d69c538a-....png \
  --prompt "a red fox sitting in fresh snow, morning light, photograph"
```

The prompt and seed nodes are found by the ids InvokeAI's UI gives them
(`positive_prompt:…`, `seed:…`). Jobs go into InvokeAI's normal queue, so they
wait behind anything already queued there.

### Imitate a reference image

```bash
image-prompt-loop refine --backend comfyui --template my-workflow-api.json \
  --reference target.png --rounds 6
```

Without `--prompt`, JoyCaption writes the first prompt from the reference. The
critic then compares each result against the reference.

## Output

Each round's image (`round-01.png`, …) and a `log.json` (prompt, score,
problems and seed for every round) are written to `--out`. By default that's a
new timestamped directory. The best prompt is printed to stdout.

The seed stays the same across rounds (use `--vary-seed` to change it), so the
differences between rounds come from the prompt. The loop stops at
`--target-score` (default 9/10) or after `--rounds`.

## Limitations

Vision models are lenient judges and can miss bad hands, garbled text, or a
wrong count of objects. The critic is asked for specific checks to reduce this,
but read the problems list instead of trusting the score alone.
