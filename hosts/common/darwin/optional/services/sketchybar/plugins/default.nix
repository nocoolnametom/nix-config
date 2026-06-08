{
  pkgs,
  sketchybar ? pkgs.sketchybar,
  configVars ? { },
  # Calendar UUIDs/names — provided by sketchybar/default.nix from
  # `services.sketchybar.personalizedOptions.calendars` (set per-host).
  calendars ? [ ],
  # Local checkout path (or null) — used by widgets that link to their own
  # plugin source file. From `services.sketchybar.personalizedOptions.repoPath`.
  repoPath ? null,
  ...
}:
rec {
  aerospace = import ./aerospace.nix { inherit pkgs sketchybar; };
  aerospace_mode = import ./aerospace_mode.nix { inherit pkgs sketchybar; };
  battery = import ./battery.nix { inherit pkgs sketchybar; };
  disk = import ./disk.nix { inherit pkgs sketchybar; };
  memory = import ./memory.nix { inherit pkgs sketchybar; };
  calendar = import ./calendar.nix {
    inherit pkgs sketchybar;
    # Calendars provided per-host via
    # `services.sketchybar.personalizedOptions.calendars`. Empty list = all.
    includedCalendars = calendars;
    # Skip patterns contain PII (names) — keep in nix-secrets.
    # Defaults applied always (see calendar.nix): "(Canceled)", "(Cancelled)",
    # "OOO", "Out of Office", "Birthday", "Holiday".
    skipPatterns = configVars.calendars.skipPatterns or [ ];
  };
  clock = import ./clock.nix { inherit pkgs sketchybar; };
  cpu = import ./cpu.nix { inherit pkgs sketchybar; };
  icon_map_fn = import ./icon_map_fn.nix { inherit pkgs sketchybar; };
  front_app = import ./front_app.nix { inherit pkgs sketchybar icon_map_fn; };
  now_playing = import ./now_playing.nix { inherit pkgs sketchybar; };
  space = import ./space.nix { inherit pkgs sketchybar; };
  space_windows = import ./space_windows.nix { inherit pkgs sketchybar icon_map_fn; };
  volume = import ./volume.nix { inherit pkgs sketchybar; };
  vpn = import ./vpn.nix { inherit pkgs sketchybar; };
  weather = import ./weather.nix { inherit pkgs sketchybar; };
  weather_click = import ./weather_click.nix {
    inherit pkgs sketchybar;
    # Prefer the working-tree source file (editable, persistent across
    # rebuilds) when repoPath is set; otherwise the script falls back to
    # the embedded /nix/store path.
    pluginWorkingPath =
      if repoPath != null then
        "${repoPath}/hosts/common/darwin/optional/services/sketchybar/plugins/weather.nix"
      else
        null;
  };
}
