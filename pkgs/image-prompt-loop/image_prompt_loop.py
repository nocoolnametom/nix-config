"""image-prompt-loop: local, self-correcting image generation.

Two commands:

  describe IMAGE
      Ask a captioning model (JoyCaption by default) to write a prompt that
      would reproduce IMAGE.

  refine (--prompt TEXT | --reference IMAGE) --backend comfyui|invokeai ...
      Render the prompt on ComfyUI or InvokeAI, show the result to a vision
      model, let it list what doesn't match and rewrite the prompt, then render
      again. Stops at --target-score or after --rounds, and keeps every round's
      image plus a JSON log in --out.

Only the Python standard library is used. All servers are reached over HTTP:
Ollama for the language/vision models, and ComfyUI or InvokeAI for rendering.
"""

import argparse
import base64
import json
import os
import random
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ENV_PREFIX = "IMAGE_PROMPT_LOOP_"

# Prompt templates from JoyCaption Beta One's caption types. JoyCaption was
# trained on these phrasings, so they work better than free-form requests.
CAPTION_STYLES = {
    "sd": "Output a stable diffusion prompt that is indistinguishable from a real stable diffusion prompt.",
    "booru": "Write a list of Booru-like tags for this image.",
    "descriptive": "Write a detailed description for this image.",
    "straightforward": (
        "Write a straightforward caption for this image. Begin with the main subject and medium. "
        "Mention pivotal elements. Omit mood and speculative wording."
    ),
}

CRITIC_SYSTEM_PROMPT = """You are a strict art director reviewing images made by a text-to-image model.
You compare the generated image against the goal and report concrete, visible problems.

Check, in this order:
1. Subjects: are all requested subjects present, and is the count right?
2. Attributes: clothing, colors, materials, expressions, poses, held objects.
3. Setting and composition: background, framing, camera angle, lighting.
4. Style and medium: photo vs illustration, art style, color palette.
5. Defects: count the legs, arms, hands and fingers you can actually see. Look for
   extra or fused limbs, impossible anatomy or posture, malformed faces, and ANY text,
   watermark, signature or logo (these are always problems unless the goal asks for them).

Only report problems you can point to in the image, judged against the goal. Don't
"correct" details the goal didn't specify using your own beliefs about how things look.
Something listed under problems must not also be listed under matches.

Scoring: 10 means every requirement is met with no defects. Take off points for each
problem. Never give 9 or 10 if any problem is listed.

When rewriting the prompt:
- Keep the original goal's intent. Never drop a requirement from the goal.
- Keep the same prompt format as the current prompt (comma-separated tags stay tags,
  prose stays prose).
- Fix the listed problems specifically: strengthen or reorder the words for missing
  elements, and describe what should be there.
- Never write negations ("no X", "without X") in revised_prompt. Image models read the
  word X and draw it. Put unwanted things (watermark, text, extra fingers, blur...) in
  negative_additions as short tags instead, and say what should be there in the prompt.
- Don't pad with generic quality words ("masterpiece", "best quality", "8k") unless the
  current prompt already uses them.
- Keep revised_prompt close to the current prompt's length: change what the problems
  require and leave the rest alone. Never repeat a phrase.
"""

# The length limits are enforced while the model generates (Ollama turns the
# schema into a grammar). Without them qwen3-vl sometimes repeats tags inside
# revised_prompt until the whole context is used up.
CRITIC_SCHEMA = {
    "type": "object",
    "properties": {
        # Listed before the score so the model reasons about problems first
        "problems": {"type": "array", "maxItems": 8, "items": {"type": "string", "maxLength": 300}},
        "matches": {"type": "array", "maxItems": 8, "items": {"type": "string", "maxLength": 300}},
        "score": {"type": "integer", "minimum": 0, "maximum": 10},
        "revised_prompt": {"type": "string", "maxLength": 1000},
        "negative_additions": {"type": "array", "maxItems": 10, "items": {"type": "string", "maxLength": 60}},
    },
    "required": ["problems", "matches", "score", "revised_prompt", "negative_additions"],
}


# "no watermark", "without text", ... in a positive prompt makes most image
# models draw the very thing, so these phrases are moved to the negative prompt
NEGATION_PATTERN = re.compile(r"^\s*(?:no|without|not|never)\s+(.+?)\s*$", re.IGNORECASE)
# "tail without black tip" -> keep "tail", move "black tip" to the negative
INNER_NEGATION_PATTERN = re.compile(r"^\s*(.+?)\s+(?:without|but no|and no)\s+(.+?)\s*$", re.IGNORECASE)


def split_negations(prompt):
    """Return (prompt without "no X" phrases, list of the X's)."""
    kept_parts, negated_terms = [], []
    for part in prompt.split(","):
        negation = NEGATION_PATTERN.match(part)
        inner_negation = INNER_NEGATION_PATTERN.match(part)
        if negation:
            negated_terms.append(negation.group(1))
        elif inner_negation:
            kept_parts.append(inner_negation.group(1))
            negated_terms.append(inner_negation.group(2))
        elif part.strip():
            kept_parts.append(part.strip())
    return ", ".join(kept_parts), negated_terms


def merge_negative(negative_prompt, new_terms):
    existing = [term.strip() for term in (negative_prompt or "").split(",") if term.strip()]
    for term in new_terms:
        term = term.strip()
        if term and term.lower() not in (known.lower() for known in existing):
            existing.append(term)
    return ", ".join(existing)


def env_default(name, fallback=None):
    return os.environ.get(ENV_PREFIX + name, fallback)


def log(message):
    print(message, file=sys.stderr, flush=True)


def http_json(url, payload=None, timeout_seconds=600):
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        raise SystemExit(f"HTTP {error.code} from {url}: {error.read().decode(errors='replace')[:2000]}")


def http_bytes(url, timeout_seconds=120):
    with urllib.request.urlopen(url, timeout=timeout_seconds) as response:
        return response.read()


def b64(image_bytes):
    return base64.b64encode(image_bytes).decode()


# ----------------------------------------------------------------- Ollama ---


def ollama_chat(ollama_url, model, system_prompt, user_prompt, images, response_schema=None, temperature=0.2, max_tokens=1500):
    payload = {
        "model": model,
        "stream": False,
        "keep_alive": "30m",
        # max_tokens is a backstop against runaway generations
        "options": {"temperature": temperature, "num_predict": max_tokens, "repeat_penalty": 1.1},
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt, "images": [b64(image) for image in images]},
        ],
    }
    if response_schema is not None:
        payload["format"] = response_schema
    reply = http_json(ollama_url.rstrip("/") + "/api/chat", payload)
    return reply["message"]["content"].strip()


def describe_image(ollama_url, model, image_bytes, style):
    return ollama_chat(
        ollama_url,
        model,
        "You are a helpful image captioner.",
        CAPTION_STYLES[style],
        [image_bytes],
        temperature=0.5,
    )


def critique(ollama_url, model, goal, current_prompt, candidate_bytes, reference_bytes=None):
    if reference_bytes is None:
        images = [candidate_bytes]
        goal_text = f"GOAL (what the image must show):\n{goal}"
        image_note = "The attached image was generated from the current prompt."
    else:
        images = [reference_bytes, candidate_bytes]
        goal_text = (
            "GOAL: the generated image should look like the REFERENCE image: same subjects, "
            "composition, setting, style and colors."
        )
        image_note = "The first attached image is the REFERENCE. The second was generated from the current prompt."
    user_prompt = f"{goal_text}\n\nCURRENT PROMPT:\n{current_prompt}\n\n{image_note}\nReview it and answer in JSON."
    # The critic ignores "keep the length" and pads revised_prompt with stock
    # quality tags, so cap it relative to the current prompt: room to fix the
    # problems, not room to bury the goal.
    prompt_budget = min(1000, max(2 * len(current_prompt), len(current_prompt) + 250))
    schema = json.loads(json.dumps(CRITIC_SCHEMA))
    schema["properties"]["revised_prompt"]["maxLength"] = prompt_budget
    raw_reply = ollama_chat(ollama_url, model, CRITIC_SYSTEM_PROMPT, user_prompt, images, schema)
    try:
        review = json.loads(raw_reply)
        revised_prompt = review["revised_prompt"].strip()
        if len(revised_prompt) >= prompt_budget - 1 and "," in revised_prompt:
            # Cut off by the cap: drop the half-written last phrase
            review["revised_prompt"] = revised_prompt.rsplit(",", 1)[0]
        return review
    except json.JSONDecodeError:
        # Hit the token limit mid-reply: report it, and keep the current prompt
        log("  (critic reply was cut off; keeping the current prompt this round)")
        return {
            "problems": ["critic reply was cut off before it finished"],
            "matches": [],
            "score": 0,
            "revised_prompt": current_prompt,
            "negative_additions": [],
        }


# ----------------------------------------------------------- ComfyUI -------


def replace_placeholders(value, replacements):
    """Swap exact-match placeholder strings anywhere in a JSON structure.

    Returns (new_value, set of placeholders found)."""
    found = set()

    def walk(node):
        if isinstance(node, dict):
            return {key: walk(child) for key, child in node.items()}
        if isinstance(node, list):
            return [walk(child) for child in node]
        if isinstance(node, str) and node in replacements:
            found.add(node)
            return replacements[node]
        return node

    return walk(value), found


class ComfyUIBackend:
    """Renders an API-format workflow ("Export (API)" in ComfyUI's menu).

    The workflow must contain the string "%PROMPT%" as the positive prompt.
    Optional: "%NEGATIVE%" for the negative prompt and "%SEED%" for the seed.
    Without "%SEED%", every input named seed or noise_seed is overwritten."""

    def __init__(self, base_url, template_path):
        self.base_url = base_url.rstrip("/")
        self.template = json.loads(Path(template_path).read_text())
        if "nodes" in self.template and "links" in self.template:
            raise SystemExit(
                f"{template_path} is a UI workflow. In ComfyUI use Workflow -> Export (API) instead."
            )

    def render(self, prompt, negative_prompt, seed):
        replacements = {"%PROMPT%": prompt, "%NEGATIVE%": negative_prompt or "", "%SEED%": seed}
        workflow, found = replace_placeholders(self.template, replacements)
        if "%PROMPT%" not in found:
            raise SystemExit('ComfyUI workflow has no "%PROMPT%" string. Put it in the positive prompt node\'s text.')
        if "%SEED%" not in found:
            for node in workflow.values():
                for seed_input in ("seed", "noise_seed"):
                    if isinstance(node.get("inputs", {}).get(seed_input), int):
                        node["inputs"][seed_input] = seed
        queued = http_json(f"{self.base_url}/prompt", {"prompt": workflow, "client_id": str(uuid.uuid4())})
        prompt_id = queued["prompt_id"]
        while True:
            history = http_json(f"{self.base_url}/history/{prompt_id}")
            if prompt_id in history:
                entry = history[prompt_id]
                status = entry.get("status", {})
                if status.get("status_str") == "error":
                    raise SystemExit(f"ComfyUI reported an error: {json.dumps(status)[:2000]}")
                if status.get("completed", True):
                    break
            time.sleep(1)
        images = [
            image
            for node_output in entry.get("outputs", {}).values()
            for image in node_output.get("images", [])
        ]
        # Prefer saved images over previews
        images.sort(key=lambda image: image.get("type") != "output")
        if not images:
            raise SystemExit("ComfyUI finished but the workflow produced no images.")
        query = urllib.parse.urlencode(
            {"filename": images[0]["filename"], "subfolder": images[0].get("subfolder", ""), "type": images[0].get("type", "output")}
        )
        return http_bytes(f"{self.base_url}/view?{query}")


# ---------------------------------------------------------- InvokeAI -------


class InvokeAIBackend:
    """Renders by re-running the graph of an image InvokeAI already generated.

    Pass --from-image with that image's name (shown in the image's info panel
    or URL), or --template with a graph JSON. The prompt and seed nodes are
    found by the ids InvokeAI's own UI gives them ("positive_prompt:…",
    "seed:…")."""

    QUEUE_ID = "default"

    def __init__(self, base_url, template_path=None, from_image=None):
        self.base_url = base_url.rstrip("/")
        if from_image:
            graph = http_json(f"{self.base_url}/api/v1/images/i/{urllib.parse.quote(from_image)}/workflow")["graph"]
        elif template_path:
            graph = json.loads(Path(template_path).read_text())
            graph = graph.get("graph", graph)
        else:
            raise SystemExit("InvokeAI needs --from-image IMAGE_NAME or --template GRAPH.json")
        # The workflow endpoint returns the graph as a JSON string
        self.graph = json.loads(graph) if isinstance(graph, str) else graph
        if not self.graph or "nodes" not in self.graph:
            raise SystemExit("No usable graph found (was that image generated by InvokeAI?).")

    def render(self, prompt, negative_prompt, seed):
        graph = json.loads(json.dumps(self.graph))
        nodes = graph["nodes"]

        prompt_nodes = [n for nid, n in nodes.items() if nid.startswith("positive_prompt:") and "value" in n]
        if not prompt_nodes:
            prompt_nodes = [n for nid, n in nodes.items() if nid.startswith(("pos_prompt:", "positive_conditioning:")) and "prompt" in n]
        if not prompt_nodes:
            raise SystemExit("Couldn't find the positive prompt node in the InvokeAI graph.")
        for node in prompt_nodes:
            node["value" if "value" in node else "prompt"] = prompt

        if negative_prompt is not None:
            negative_nodes = [n for nid, n in nodes.items() if nid.startswith("negative_prompt:") and "value" in n]
            negative_nodes += [n for nid, n in nodes.items() if nid.startswith("neg_prompt:") and "prompt" in n]
            if not negative_nodes:
                log("  (this graph has no negative prompt node; --negative ignored)")
            for node in negative_nodes:
                node["value" if "value" in node else "prompt"] = negative_prompt

        seed_nodes = [n for nid, n in nodes.items() if nid.startswith("seed:") and "value" in n]
        for node in seed_nodes:
            node["value"] = seed
        if not seed_nodes:
            for node in nodes.values():
                if isinstance(node.get("seed"), int):
                    node["seed"] = seed

        # Keep the gallery metadata truthful about what was actually rendered
        for node in nodes.values():
            if node.get("type") == "core_metadata":
                node["positive_prompt"] = prompt
                node["seed"] = seed
                if negative_prompt is not None:
                    node["negative_prompt"] = negative_prompt

        queued = http_json(
            f"{self.base_url}/api/v1/queue/{self.QUEUE_ID}/enqueue_batch",
            {"batch": {"graph": graph, "runs": 1, "origin": "image-prompt-loop"}, "prepend": False},
        )
        item_id = queued["item_ids"][0]
        while True:
            item = http_json(f"{self.base_url}/api/v1/queue/{self.QUEUE_ID}/i/{item_id}")
            if item["status"] == "completed":
                break
            if item["status"] in ("failed", "canceled"):
                raise SystemExit(f"InvokeAI queue item {item['status']}: {item.get('error_message') or ''}")
            time.sleep(1)

        session = item["session"]
        results = session.get("results", {})
        prepared_ids_by_source = session.get("source_prepared_mapping", {})
        # Prefer images from nodes that write to the gallery (not intermediates)
        final_image_names = [
            results[prepared_id]["image"]["image_name"]
            for source_id, node in nodes.items()
            if not node.get("is_intermediate", False)
            for prepared_id in prepared_ids_by_source.get(source_id, [])
            if "image" in results.get(prepared_id, {})
        ]
        any_image_names = [result["image"]["image_name"] for result in results.values() if "image" in result]
        image_names = final_image_names or any_image_names
        if not image_names:
            raise SystemExit("InvokeAI finished but produced no image.")
        return http_bytes(f"{self.base_url}/api/v1/images/i/{urllib.parse.quote(image_names[-1])}/full")


# ---------------------------------------------------------- commands -------


def command_describe(args):
    image_bytes = Path(args.image).read_bytes()
    print(describe_image(args.ollama, args.caption_model, image_bytes, args.style))


def command_refine(args):
    if not args.prompt and not args.reference:
        raise SystemExit("refine needs --prompt, --reference, or both.")
    if args.backend == "comfyui":
        if not args.comfyui:
            raise SystemExit(f"Set --comfyui or {ENV_PREFIX}COMFYUI_URL")
        if not args.template:
            raise SystemExit("ComfyUI needs --template WORKFLOW_API.json")
        backend = ComfyUIBackend(args.comfyui, args.template)
    else:
        if not args.invokeai:
            raise SystemExit(f"Set --invokeai or {ENV_PREFIX}INVOKEAI_URL")
        backend = InvokeAIBackend(args.invokeai, args.template, args.from_image)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    reference_bytes = Path(args.reference).read_bytes() if args.reference else None

    if args.prompt:
        current_prompt = args.prompt
    else:
        log(f"Describing reference with {args.caption_model} ...")
        current_prompt = describe_image(args.ollama, args.caption_model, reference_bytes, args.style)
    goal = args.prompt or "(match the reference image)"
    current_negative = args.negative
    seed = args.seed if args.seed is not None else random.randint(0, 2**31 - 1)

    history = []
    best = None
    for round_number in range(1, args.rounds + 1):
        if args.vary_seed and round_number > 1:
            seed = random.randint(0, 2**31 - 1)
        log(f"\nRound {round_number}/{args.rounds} (seed {seed})\n  prompt: {current_prompt}")
        if current_negative:
            log(f"  negative: {current_negative}")
        image_bytes = backend.render(current_prompt, current_negative, seed)
        image_path = out_dir / f"round-{round_number:02d}.png"
        image_path.write_bytes(image_bytes)

        review = critique(args.ollama, args.critic_model, goal, current_prompt, image_bytes, reference_bytes)
        log(f"  score: {review['score']}/10")
        for problem in review["problems"]:
            log(f"  - {problem}")

        record = {
            "round": round_number,
            "seed": seed,
            "prompt": current_prompt,
            "negative": current_negative,
            "image": image_path.name,
            "score": review["score"],
            "problems": review["problems"],
            "matches": review["matches"],
            "revised_prompt": review["revised_prompt"],
            "negative_additions": review["negative_additions"],
        }
        history.append(record)
        if best is None or record["score"] > best["score"]:
            best = record
        (out_dir / "log.json").write_text(json.dumps({"goal": goal, "best": best, "rounds": history}, indent=2))

        if review["score"] >= args.target_score:
            log(f"  reached target score {args.target_score}")
            break
        revised_prompt, negated_terms = split_negations(review["revised_prompt"])
        current_prompt = revised_prompt or current_prompt
        current_negative = merge_negative(current_negative, review["negative_additions"] + negated_terms)

    log(f"\nBest: round {best['round']}, score {best['score']}/10 -> {out_dir / best['image']}")
    if best["negative"]:
        log(f"Best negative prompt: {best['negative']}")
    print(best["prompt"])


def main():
    # Shared options go on every subcommand, so they can be given after it
    # (image-prompt-loop describe --style booru photo.png)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--ollama", default=env_default("OLLAMA_URL", "http://localhost:11434"), help="Ollama URL")
    common.add_argument(
        "--caption-model",
        default=env_default("CAPTION_MODEL", "aha2025/llama-joycaption-beta-one-hf-llava:Q6_K"),
        help="vision model for image -> prompt",
    )
    common.add_argument(
        "--critic-model",
        default=env_default("CRITIC_MODEL", "qwen3-vl:30b-a3b-instruct"),
        help="vision model that reviews images and rewrites prompts",
    )
    common.add_argument("--style", choices=sorted(CAPTION_STYLES), default="sd", help="prompt style for image -> prompt (default sd)")

    parser = argparse.ArgumentParser(prog="image-prompt-loop", description=__doc__.split("\n\n")[0])
    subcommands = parser.add_subparsers(dest="command", required=True)

    describe = subcommands.add_parser("describe", parents=[common], help="write a prompt that would reproduce an image")
    describe.add_argument("image")
    describe.set_defaults(handler=command_describe)

    refine = subcommands.add_parser("refine", parents=[common], help="render, critique and rewrite the prompt in a loop")
    refine.add_argument("--prompt", help="what the image should show (the goal; kept for every round)")
    refine.add_argument("--reference", help="image to imitate; without --prompt it is described first")
    refine.add_argument("--negative", help="negative prompt (fixed across rounds)")
    refine.add_argument("--backend", choices=["comfyui", "invokeai"], default=env_default("BACKEND", "comfyui"))
    refine.add_argument("--comfyui", default=env_default("COMFYUI_URL"), help="ComfyUI URL")
    refine.add_argument("--invokeai", default=env_default("INVOKEAI_URL"), help="InvokeAI URL")
    refine.add_argument("--template", help="ComfyUI API-format workflow, or an InvokeAI graph JSON")
    refine.add_argument("--from-image", help="InvokeAI: reuse the graph of this gallery image")
    refine.add_argument("--rounds", type=int, default=5)
    refine.add_argument("--target-score", type=int, default=9)
    refine.add_argument("--seed", type=int, help="fixed seed (default: random, then kept for every round)")
    refine.add_argument("--vary-seed", action="store_true", help="new seed every round instead of a fixed one")
    refine.add_argument("--out", default=f"image-prompt-loop-{time.strftime('%Y%m%d-%H%M%S')}")
    refine.set_defaults(handler=command_refine)

    args = parser.parse_args()
    args.handler(args)


if __name__ == "__main__":
    main()
