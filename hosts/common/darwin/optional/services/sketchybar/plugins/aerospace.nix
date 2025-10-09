{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
writeShellScript "sketchybar_aerospace" ''
  if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set $NAME background.drawing=on
  else
    sketchybar --set $NAME background.drawing=off
  fi
''
