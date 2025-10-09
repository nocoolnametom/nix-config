{
  pkgs,
  writeShellScript ? pkgs.writeShellScript,
  icon_map_fn,
  ...
}:
writeShellScript "sketchybar_space_windows" ''
  if [ "$SENDER" = "aerospace_workspace_change" ]; then
    prevapps=$(aerospace list-windows --workspace "$PREV_WORKSPACE" | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')
    if [ "${"$"}{prevapps}" != "" ]; then
      sketchybar --set space.$PREV_WORKSPACE drawing=on
      icon_strip=" "
      while read -r app; do
        icon_strip+=" $(${icon_map_fn} "$app")"
      done <<<"${"$"}{prevapps}"
      sketchybar --set space.$PREV_WORKSPACE label="$icon_strip"
    fi
  else
    FOCUSED_WORKSPACE="$(aerospace list-workspaces --focused)"
  fi

  # Hide empty workspaces in every monitor
  MONITOR_COUNT="$(aerospace list-monitors --count)"
  for m in $(seq 1 $MONITOR_COUNT); do
    for i in $(aerospace list-workspaces --monitor $m --empty); do
      # Hide empty workspaces if not the focused workspace
      if [ "$i" != "$FOCUSED_WORKSPACE" ]; then
        sketchybar --set space.$i display=0
      fi
    done
  done

  apps=$(aerospace list-windows --workspace "$FOCUSED_WORKSPACE" | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')
  sketchybar --set space.$FOCUSED_WORKSPACE drawing=on
  icon_strip=" "
  if [ "${"$"}{apps}" != "" ]; then
    while read -r app; do
      icon_strip+=" $(${icon_map_fn} "$app")"
    done <<<"${"$"}{apps}"
  else
    icon_strip=""
  fi
  sketchybar --set space.$FOCUSED_WORKSPACE label="$icon_strip"
''
