# smolcoder: zero-config local LLM coding agent (Ollama / LM Studio)
#
# On machines that don't run Ollama locally, this module pre-seeds
# ~/.smolcoder.json with barliman as a known remote model host so that
# `/models` in the TUI already knows where to look.
#
# The file is created only once (on first activation); smolcoder manages it at
# runtime and will add sessions, models, etc. to it — HM must not overwrite
# those subsequent changes.
#
# Security note: smolcoder's web UI (--web) binds to 127.0.0.1 only and is
# protected by a random URL token regenerated at every start.  Do NOT expose
# it to the public internet even behind an OIDC proxy — edit mode provides
# arbitrary shell command execution.  Access it via SSH tunnel or Tailscale.
{
  pkgs,
  lib,
  configVars,
  ...
}:
{
  home.packages = [ pkgs.smolcoder ];

  home.activation.smolcoderRemoteHost = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        CONFIG_FILE="$HOME/.smolcoder.json"
        if [ ! -f "$CONFIG_FILE" ]; then
          cat > "$CONFIG_FILE" <<'SMOLCFG'
    {
      "hosts": [
        {
          "address": "barliman.${configVars.homeLanDomain}",
          "name": "barliman (AI Max 300)"
        }
      ]
    }
    SMOLCFG
          $VERBOSE_ECHO "smolcoder: created ~/.smolcoder.json with barliman as remote Ollama host"
        fi
  '';
}
