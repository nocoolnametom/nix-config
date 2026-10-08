{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Set by hosts/common/optional/amd-unified-memory.nix when that's imported
  gpuMemoryGiB = config.hardware.amdUnifiedMemory.gpuMemoryGiB or null;
  ollamaContextLength = config.services.ollama.environmentVariables.OLLAMA_CONTEXT_LENGTH or null;

  # llmfit has no environment variable for its memory override, only the
  # --memory flag. On AMD unified-memory APUs it treats all OS-visible RAM as GPU
  # memory, ignoring the kernel's GTT limit, so the installed command is wrapped
  # to pass the real limit. It does read OLLAMA_CONTEXT_LENGTH from the
  # environment, but that's only set inside the ollama service, so the wrapper
  # supplies it too (a value already in the shell still wins).
  # `nix-shell -p llmfit` bypasses this wrapper.
  wrapFlags =
    lib.optional (gpuMemoryGiB != null) "--add-flags \"--memory ${toString gpuMemoryGiB}G\""
    ++ lib.optional (
      ollamaContextLength != null
    ) "--set-default OLLAMA_CONTEXT_LENGTH ${ollamaContextLength}";

  llmfit =
    if wrapFlags == [ ] then
      pkgs.llmfit
    else
      pkgs.symlinkJoin {
        name = "llmfit-wrapped";
        paths = [ pkgs.llmfit ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/llmfit ${lib.concatStringsSep " " wrapFlags}
        '';
      };

  # `llmfit recommend` reports Hugging Face repo names. The Hugging Face ->
  # Ollama tag table llmfit uses for its own TUI downloads isn't exposed on the
  # command line, so it's pulled out of the matching source at build time.
  ollamaTagMap = pkgs.runCommand "llmfit-ollama-tags.tsv" { nativeBuildInputs = [ pkgs.perl ]; } ''
    sed -n '/^const OLLAMA_MAPPINGS/,/^];/p' ${pkgs.llmfit.src}/llmfit-core/src/providers.rs \
      | perl -0ne 'while(/\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,?\s*\)/g){print "$1\t$2\n"}' > $out
    # Fail the build if llmfit restructured the table and nothing matched
    test "$(wc -l < $out)" -gt 20
  '';

  # Picks the best-scoring model per use case that has an Ollama tag, and prints
  # (or writes into a machineLLMs file) a generated block of Ollama models, as
  # "<name>" = "<name>"; entries of that file's { intendedName = actualName; } attrset.
  #
  # llmfit's catalog lists Hugging Face repos, including FP8/NVFP4/MLX copies of
  # the same model that Ollama can't load; those have no Ollama tag and are
  # skipped. llmfit also picks the quantization that fits ("best_quant"), but an
  # Ollama library tag downloads Ollama's default, normally Q4_K_M. When llmfit
  # says only something smaller fits (Q2_K, Q3_K_M), the library tag would be too
  # big, so this looks for a single-file GGUF at llmfit's quantization on Hugging
  # Face instead and emits an hf.co/<repo>:<QUANT> reference, which `ollama pull`
  # accepts. Split (multi-part) GGUFs are passed over: Ollama can't pull them.
  llmfitOllamaPicks = pkgs.writeShellApplication {
    name = "llmfit-ollama-picks";
    runtimeInputs = [
      llmfit
      pkgs.jq
      pkgs.gawk
      pkgs.coreutils
      pkgs.curl
      pkgs.gnugrep
    ];
    text = ''
      usage() {
        cat <<'EOF'
      Usage: llmfit-ollama-picks [-n PER_CATEGORY] [-c "CATEGORIES"] [-f MIN_FIT] [--write FILE]

      Asks llmfit for the best-fitting models per use case, keeps only those with
      a known Ollama tag, and prints "<name>" = "<name>"; entries for a
      machineLLMs attrset.

        -n N         models per category (default 1)
        -c "LIST"    space-separated categories (default:
                     "general coding reasoning chat multimodal embedding")
        -f FIT       minimum llmfit fit level: perfect, good, marginal (default good)
        --write FILE replace the block between the "# BEGIN llmfit-picks" and
                     "# END llmfit-picks" markers in FILE (inserted after the
                     opening "{" on first run). Everything else in FILE is kept.
                     Picks already listed elsewhere in FILE (as either name)
                     are written commented out, so no model is listed twice.
      EOF
      }

      per_category=1
      categories="general coding reasoning chat multimodal embedding"
      min_fit="good"
      write_file=""
      while [ $# -gt 0 ]; do
        case "$1" in
          -n) per_category="$2"; shift 2 ;;
          -c) categories="$2"; shift 2 ;;
          -f) min_fit="$2"; shift 2 ;;
          --write) write_file="$2"; shift 2 ;;
          -h|--help) usage; exit 0 ;;
          *) usage >&2; exit 1 ;;
        esac
      done

      # Orders quantizations by size. Rank 4 is Q4_K_M, what an Ollama library
      # tag downloads by default; anything ranked lower needs a GGUF instead.
      # Unknown names rank 0, so they also go through the GGUF search.
      quant_rank() {
        case "$1" in
          Q2_K) echo 2 ;;
          Q3_K_S|Q3_K_M|Q3_K_L|Q4_0|Q4_K_S) echo 3 ;;
          Q4_K_M) echo 4 ;;
          Q5_K_S|Q5_K_M) echo 5 ;;
          Q6_K) echo 6 ;;
          Q8_0) echo 8 ;;
          F16|BF16|F32) echo 16 ;;
          *) echo 0 ;;
        esac
      }

      # Prints hf.co/<repo>:<QUANT> for the first Hugging Face repo holding a
      # single-file GGUF of the model at that quantization, or nothing. Tries
      # llmfit's own GGUF sources first, then repos named <model>-GGUF (e.g.
      # unsloth/Qwen3-Coder-Next-GGUF, bartowski/Qwen_Qwen3-Coder-Next-GGUF).
      find_gguf() {
        local hf_name="$1" quant="$2" known_sources="$3"
        local base searched candidate files
        base="$(basename "$hf_name")"
        searched="$(curl -fsS --max-time 20 "https://huggingface.co/api/models?search=$base-GGUF&limit=20" \
          | jq -r --arg base "$base" '
              (($base + "-gguf") | ascii_downcase) as $suffix
              | .[].id | select(ascii_downcase as $id
                  | any("/", "_", "."; . as $sep | $id | endswith($sep + $suffix)))' \
          || true)"
        while read -r candidate; do
          [ -n "$candidate" ] && [ "$candidate" != "-" ] || continue
          files="$(curl -fsS --max-time 20 "https://huggingface.co/api/models/$candidate" \
            | jq -r '.siblings[].rfilename' || true)"
          # A top-level file ending in -<QUANT>.gguf: not in a subfolder and
          # not split into -00001-of-0000N parts
          if echo "$files" | grep -qiE "^[^/]*-$quant\.gguf$"; then
            echo "hf.co/$candidate:$quant"
            return 0
          fi
        done < <(printf '%s\n%s\n' "$(echo "$known_sources" | tr ',' '\n')" "$searched" | awk '!seen[$0]++')
      }

      # Ollama treats "name" and "name:latest" as the same model, and names
      # are case-insensitive, so compare them in one canonical form
      normalize_ref() {
        local ref
        ref="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
        echo "''${ref%:latest}"
      }

      # With --write, collect the models FILE already lists outside the
      # generated block (comments stripped), so picks can skip duplicates
      listed_outside_block=" "
      if [ -n "$write_file" ]; then
        while read -r listed_ref; do
          listed_outside_block="$listed_outside_block$(normalize_ref "$listed_ref") "
        done < <(awk '/# BEGIN llmfit-picks/ { skipping = 1 } !skipping { print } /# END llmfit-picks/ { skipping = 0 }' "$write_file" \
                   | sed 's/#.*//' | grep -oE '"[^"]+"' | tr -d '"' || true)
      fi

      tag_map="${ollamaTagMap}"
      generated_block="$(mktemp)"
      trap 'rm -f "$generated_block"' EXIT
      already_picked=" "

      {
        echo "  # BEGIN llmfit-picks - generated $(date +%F) by llmfit-ollama-picks; edits inside are overwritten"
        for category in $categories; do
          picked_in_category=0
          # -n 300: most of llmfit's catalog has no Ollama tag, so look deep.
          # Every field before capabilities is non-empty ("-" for no GGUF
          # sources): read collapses consecutive tabs, which would shift columns.
          while IFS=$'\t' read -r hf_name score tokens_per_sec memory_gb best_quant gguf_sources capabilities; do
            repo="$(basename "$hf_name" | tr '[:upper:]' '[:lower:]')"
            ollama_tag="$(awk -F'\t' -v repo="$repo" '$1 == repo { print $2; exit }' "$tag_map")"
            [ -n "$ollama_tag" ] || continue
            # The same model can top several categories; list it once
            case "$already_picked" in *" $ollama_tag "*) continue ;; esac
            already_picked="$already_picked$ollama_tag "
            model_ref="$ollama_tag"
            if [ "$(quant_rank "$best_quant")" -lt 4 ]; then
              model_ref="$(find_gguf "$hf_name" "$best_quant" "$gguf_sources")"
              if [ -z "$model_ref" ]; then
                echo "  # skipped $category: $hf_name only fits at $best_quant, smaller than the Q4_K_M that \"$ollama_tag\" downloads, and no single-file $best_quant GGUF was found"
                continue
              fi
            fi
            echo "  # $category: $hf_name - score $score, ~$tokens_per_sec tok/s, ~''${memory_gb} GB at $best_quant''${capabilities:+ [$capabilities]}"
            # Still counts toward -n: it's one of this category's top picks,
            # just one the file already has
            case "$listed_outside_block" in
              *" $(normalize_ref "$model_ref") "*) echo "  # \"$model_ref\" = \"$model_ref\"; - already listed outside this block" ;;
              *) echo "  \"$model_ref\" = \"$model_ref\";" ;;
            esac
            picked_in_category=$((picked_in_category + 1))
            [ "$picked_in_category" -lt "$per_category" ] || break
          done < <(llmfit recommend --use-case "$category" -n 300 --min-fit "$min_fit" \
                     | jq -r '.models[] | [.name, .score, .estimated_tps, .memory_required_gb, .best_quant,
                         ((.gguf_sources // []) | map(.repo) | if length == 0 then "-" else join(",") end),
                         ((.capability_ids // []) | join(","))] | @tsv')
        done
        echo "  # END llmfit-picks"
      } > "$generated_block"

      if [ -z "$write_file" ]; then
        cat "$generated_block"
        exit 0
      fi

      updated_file="$(mktemp)"
      if grep -q '# BEGIN llmfit-picks' "$write_file"; then
        awk -v block="$generated_block" '
          /# BEGIN llmfit-picks/ { while ((getline line < block) > 0) print line; skipping = 1; next }
          /# END llmfit-picks/ { skipping = 0; next }
          !skipping { print }
        ' "$write_file" > "$updated_file"
      else
        awk -v block="$generated_block" '
          { print }
          !inserted && /^\{[[:space:]]*$/ { while ((getline line < block) > 0) print line; print ""; inserted = 1 }
        ' "$write_file" > "$updated_file"
      fi
      # cat (not mv) keeps the original file's permissions
      cat "$updated_file" > "$write_file"
      rm -f "$updated_file"
      echo "Updated $write_file - review with your VCS diff before committing." >&2
    '';
  };
in
{
  environment.systemPackages = [
    llmfit
    llmfitOllamaPicks
  ];
}
