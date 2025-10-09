{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  ...
}:
writeShellScript "sketchybar_front_app" ''
  source "${pkgs.sketchybar-app-font}/bin/icon_map.sh"

  __icon_map "$1"

  echo "$icon_result"
''
