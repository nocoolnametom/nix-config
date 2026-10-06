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
  # (or writes into a machineLLMs list) a generated block of Ollama references.
  llmfitOllamaPicks = pkgs.writeShellApplication {
    name = "llmfit-ollama-picks";
    runtimeInputs = [
      llmfit
      pkgs.jq
      pkgs.gawk
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      usage() {
        cat <<'EOF'
      Usage: llmfit-ollama-picks [-n PER_CATEGORY] [-c "CATEGORIES"] [-f MIN_FIT] [--write FILE]

      Asks llmfit for the best-fitting models per use case, keeps only those with
      a known Ollama tag, and prints a Nix list block for a machineLLMs file.

        -n N         models per category (default 1)
        -c "LIST"    space-separated categories (default:
                     "general coding reasoning chat multimodal embedding")
        -f FIT       minimum llmfit fit level: perfect, good, marginal (default good)
        --write FILE replace the block between the "# BEGIN llmfit-picks" and
                     "# END llmfit-picks" markers in FILE (inserted after the
                     opening "[" on first run). Everything else in FILE is kept.
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

      tag_map="${ollamaTagMap}"
      generated_block="$(mktemp)"
      trap 'rm -f "$generated_block"' EXIT
      already_picked=" "

      {
        echo "  # BEGIN llmfit-picks - generated $(date +%F) by llmfit-ollama-picks; edits inside are overwritten"
        for category in $categories; do
          picked_in_category=0
          # -n 300: most of llmfit's catalog has no Ollama tag, so look deep
          while IFS=$'\t' read -r hf_name score tokens_per_sec memory_gb capabilities; do
            repo="$(basename "$hf_name" | tr '[:upper:]' '[:lower:]')"
            ollama_tag="$(awk -F'\t' -v repo="$repo" '$1 == repo { print $2; exit }' "$tag_map")"
            [ -n "$ollama_tag" ] || continue
            # The same model can top several categories; list it once
            case "$already_picked" in *" $ollama_tag "*) continue ;; esac
            already_picked="$already_picked$ollama_tag "
            echo "  # $category: $hf_name - score $score, ~$tokens_per_sec tok/s, ~''${memory_gb} GB''${capabilities:+ [$capabilities]}"
            echo "  \"$ollama_tag\""
            picked_in_category=$((picked_in_category + 1))
            [ "$picked_in_category" -lt "$per_category" ] || break
          done < <(llmfit recommend --use-case "$category" -n 300 --min-fit "$min_fit" \
                     | jq -r '.models[] | [.name, .score, .estimated_tps, .memory_required_gb, ((.capability_ids // []) | join(","))] | @tsv')
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
          !inserted && /^\[/ { while ((getline line < block) > 0) print line; print ""; inserted = 1 }
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
