{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  # Optional working-tree path to the user's checkout's `weather.nix`. When
  # set, the click handler tries this path first; if the file is missing
  # at click time it falls back to the embedded /nix/store path.
  pluginWorkingPath ? null,
  ...
}:
let
  # /nix/store path is interpolated directly below via `${./weather.nix}`
  # in the script body. Going through `toString` drops the string context
  # that Nix uses to track the dependency, which produces a warning and
  # leaves the dependency uncovered by GC roots — so we don't do that.
  workingPath = if pluginWorkingPath != null then pluginWorkingPath else "";
in
# Click handler for the weather widget. Two modes:
#  - "Sketchybar Weather" Shortcut exists  → open Weather.app
#  - Shortcut missing                       → show setup dialog
writeShellScript "sketchybar_weather_click" ''
    if /usr/bin/shortcuts list 2>/dev/null | grep -qFx "Sketchybar Weather"; then
      /usr/bin/open -b com.apple.weather
      exit 0
    fi

    # Setup dialog. Two source paths are baked in: the user's working-tree
    # checkout (preferred — editable, persistent across rebuilds) and the
    # /nix/store path (always present, used as fallback if the working-tree
    # file isn't there). At click time we pick whichever exists.
    PLUGIN_SOURCE_WORKING='${workingPath}'
    PLUGIN_SOURCE_STORE='${./weather.nix}'
    if [ -n "$PLUGIN_SOURCE_WORKING" ] && [ -f "$PLUGIN_SOURCE_WORKING" ]; then
      PLUGIN_SOURCE="$PLUGIN_SOURCE_WORKING"
    else
      PLUGIN_SOURCE="$PLUGIN_SOURCE_STORE"
    fi

    CHOICE=$(/usr/bin/osascript <<'APPLESCRIPT' 2>/dev/null
  try
    set msg to "The weather widget needs a macOS Shortcut named " & quote & "Sketchybar Weather" & quote & "." & return & return & ¬
      "In Shortcuts.app, create a new Shortcut with these actions:" & return & return & ¬
      "  1. Get Current Weather  (uses current location)" & return & ¬
      "  2. Get Details of Weather Conditions → Temperature" & return & ¬
      "  3. Get Details of Weather Conditions → Conditions" & return & ¬
      "  4. Text:  [Temperature] [Conditions]" & return & ¬
      "  5. Stop and output → Text" & return & return & ¬
      "Grant Location permission on first run." & return & ¬
      "The widget polls every 10 minutes once the Shortcut exists."
    set theResult to display dialog msg with title "Weather widget setup" buttons {"View plugin source", "Cancel", "Open Shortcuts.app"} default button "Open Shortcuts.app" cancel button "Cancel"
    return button returned of theResult
  on error
    return ""
  end try
  APPLESCRIPT
    )

    case "$CHOICE" in
      "Open Shortcuts.app") /usr/bin/open -a Shortcuts ;;
      "View plugin source") /usr/bin/open "$PLUGIN_SOURCE" ;;
    esac
''
