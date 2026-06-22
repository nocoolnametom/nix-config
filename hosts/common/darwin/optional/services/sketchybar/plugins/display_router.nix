{
  pkgs,
  config,
  sketchybar ? pkgs.sketchybar,
  # Baseline bar height when no notched display is attached.
  baselineHeight ? 30,
  # List of sketchybar item names to apply compact padding to.
  compactPaddingItems ? [ ],
  ...
}:
let
  displayInfo = "${pkgs.display-info}/bin/display-info";
  sketchybarBin = "${sketchybar}/bin/sketchybar";
  # Bash array literal of item names, ready to be embedded in the
  # heredoc as `items=( <list> )`.
  itemsBash = builtins.concatStringsSep " " (map (n: ''"${n}"'') compactPaddingItems);
in
pkgs.writeShellScript "sketchybar_display_router" ''
  # Runs once at sketchybar startup and on every `display_change` event.
  # Computes the bar height from display-info's reported notch inset,
  # writes the built-in display index to a flag file consumed by
  # compact-mode widget scripts, and routes per-item padding overrides.

  set -u

  # Read display info into shell variables.
  eval "$(${displayInfo})"

  # Bar height: max(NOTCH_INSET, baselineHeight).
  baseline=${toString baselineHeight}
  if [ "''${NOTCH_INSET:-0}" -gt "$baseline" ]; then
    height="$NOTCH_INSET"
  else
    height="$baseline"
  fi

  ${sketchybarBin} --bar height="$height"

  # Flag file for compact-mode widget scripts. Empty when no built-in.
  flag_file="/tmp/sketchybar-builtin-display"
  printf '%s' "''${BUILTIN_DISPLAY:-}" > "$flag_file"

  # Padding routing — halve horizontal padding bar-wide when the
  # built-in display is attached, restore to defaults otherwise. Per-
  # display padding overrides aren't supported by sketchybar, so the
  # compact spacing applies on all displays whenever the built-in is
  # present (accepted trade-off — fits the bar within the notch
  # geometry).
  items=( ${itemsBash} )
  if [ -n "''${BUILTIN_DISPLAY:-}" ]; then
    # Halved spacing.
    for item in "''${items[@]}"; do
      ${sketchybarBin} --set "$item" \
        padding_left=2 padding_right=2 \
        icon.padding_left=2 icon.padding_right=2 \
        label.padding_left=2 label.padding_right=2
    done
  else
    # Default spacing — matches the `default=(...)` block in the
    # sketchybar config.
    for item in "''${items[@]}"; do
      ${sketchybarBin} --set "$item" \
        padding_left=5 padding_right=5 \
        icon.padding_left=4 icon.padding_right=4 \
        label.padding_left=4 label.padding_right=4
    done
  fi
''
