{
  lib,
  python3,
  writeShellApplication,
  writeText,
}:

# Watcher for the live slk Slack cache (~/.local/share/slk/cache.db).
# Emits JSON candidate events (DMs, @mentions, alert-channel posts) newer
# than a persisted watermark; Hermes cron triages the output and only pings
# a human when something needs immediate attention. stdlib-only Python.
writeShellApplication {
  name = "slack-watch";

  runtimeInputs = [ python3 ];

  text = ''
    exec ${python3.interpreter} ${writeText "slack-watch.py" (builtins.readFile ./slack-watch.py)} "$@"
  '';

  meta = {
    description = "Emit Slack candidate events from the live slk SQLite cache";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
