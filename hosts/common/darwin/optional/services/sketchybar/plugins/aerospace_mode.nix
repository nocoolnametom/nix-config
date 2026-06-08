{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
# Updates the mode indicator on `aerospace_mode_change` events. Triggered by
# bindings in aerospace/default.nix via `exec-and-forget sketchybar --trigger
# aerospace_mode_change MODE=<name>`. Hidden when MODE=main (or unset).
#
# Add a new mode: append a `case` branch below. Tweak a color: edit the value
# in the corresponding branch. ARGB hex: 0xAARRGGBB.
writeShellScript "sketchybar_aerospace_mode" ''
  MODE="''${MODE:-main}"

  case "$MODE" in
    alter)
      sketchybar --set "$NAME" \
        drawing=on \
        label="ALTER" \
        label.color=0xff000000 \
        background.color=0xffe09000 \
        background.drawing=on
      ;;
    service)
      sketchybar --set "$NAME" \
        drawing=on \
        label="SERVICE" \
        label.color=0xffffffff \
        background.color=0xff4488cc \
        background.drawing=on
      ;;
    resize)
      sketchybar --set "$NAME" \
        drawing=on \
        label="RESIZE" \
        label.color=0xffffffff \
        background.color=0xffcc4444 \
        background.drawing=on
      ;;
    main|*)
      sketchybar --set "$NAME" drawing=off
      ;;
  esac
''
