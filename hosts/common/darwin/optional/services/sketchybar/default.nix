{
  lib,
  pkgs,
  config,
  ...
}:
let
  plugins = import ./plugins {
    inherit pkgs;
    sketchybar = config.services.sketchybar.package;
  };
  aerospace = "${config.services.aerospace.package}/bin/aerospace";
in
{
  services.sketchybar.enable = lib.mkDefault true;
  services.sketchybar.extraPackages = lib.mkDefault [
    config.services.aerospace.package
    pkgs.jq
  ];
  fonts.packages = [ pkgs.sketchybar-app-font ];
  services.sketchybar.config = lib.mkDefault ''
    ##### Bar Appearance #####
    # Configuring the general appearance of the bar.
    # These are only some of the options available. For all options see:
    # https://felixkratz.github.io/SketchyBar/config/bar
    # If you are looking for other colors, see the color picker:
    # https://felixkratz.github.io/SketchyBar/config/tricks#color-picker

    sketchybar --bar position=top height=40 blur_radius=30 color=0x40000000

    ##### Changing Defaults #####
    # We now change some default values, which are applied to all further items.
    # For a full list of all available item properties see:
    # https://felixkratz.github.io/SketchyBar/config/items

    default=(
      padding_left=5
      padding_right=5
      icon.font="SFProDisplay Nerd Font:Bold:15.0"
      label.font="SFProDisplay Nerd Font:Semibold:15.0"
      icon.color=0xffffffff
      label.color=0xffffffff
      icon.padding_left=4
      icon.padding_right=4
      label.padding_left=4
      label.padding_right=4
    )
    sketchybar --default "${"$"}{default[@]}"

    ##### Adding Aerospace Space Indicators #####
    # Let's add some aerospace spaces:
    # https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item
    # to indicate active and available aerospace spaces.
    sketchybar --add event aerospace_workspace_change

    for sid in $(aerospace list-workspaces --all); do
      sketchybar --add item space.$sid left \
        --subscribe space.$sid aerospace_workspace_change \
        --set space.$sid \
        drawing=off \
        background.color=0x44ffffff \
        background.corner_radius=5 \
        background.drawing=on \
        background.border_color=0xAAFFFFFF \
        background.border_width=0 \
        background.height=25 \
        icon="$sid" \
        icon.padding_left=10 \
        label.font="sketchybar-app-font:Regular:16.0" \
        label.padding_right=20 \
        label.padding_left=0 \
        label.y_offset=-1 \
        click_script="aerospace workspace $sid" \
        script="${plugins.aerospace} $sid"
    done

    # Load Icons on startup
    for sid in $(aerospace list-workspaces --monitor $mid --empty no); do
    apps=$(aerospace list-windows --workspace "$sid" | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')

    sketchybar --set space.$sid drawing=on

    icon_strip=" "
    if [ "${"$"}{apps}" != "" ]; then
      while read -r app; do
        icon_strip+=" $(${plugins.icon_map_fn} "$app")"
      done <<<"${"$"}{apps}"
    else
      icon_strip=""
    fi
    sketchybar --set space.$sid label="$icon_strip"
    done

    sketchybar --add item space_separator left \
      --set space_separator \
      label.drawing=off \
      background.drawing=off \
      script="${plugins.space_windows}" \
      --subscribe space_separator aerospace_workspace_change front_app_switched space_windows_change

    ##### Adding Left Items #####
    # We add some regular items to the left side of the bar, where
    # only the properties deviating from the current defaults need to be set

    sketchybar --add item chevron left \
              --set chevron icon= label.drawing=off \
              --add item front_app left \
              --set front_app icon.font="sketchybar-app-font:Regular:15.0" \
                script="${plugins.front_app}" \
              --subscribe front_app front_app_switched

    ##### Adding Right Items #####
    # In the same way as the left items we can add items to the right side.
    # Additional position (e.g. center) are available, see:
    # https://felixkratz.github.io/SketchyBar/config/items#adding-items-to-sketchybar

    # Some items refresh on a fixed cycle, e.g. the clock runs its script once
    # every 10s. Other items respond to events they subscribe to, e.g. the
    # volume.sh script is only executed once an actual change in system audio
    # volume is registered. More info about the event system can be found here:
    # https://felixkratz.github.io/SketchyBar/config/events

    sketchybar --add item clock right \
              --set clock update_freq=10 icon=  script="${plugins.clock}" \
              --add item battery right \
              --set battery update_freq=120 script="${plugins.battery}" \
              --subscribe battery system_woke power_source_change \
              --add item cpu right \
              --set cpu update_freq=5 icon= script="${plugins.cpu}"

    ##### Force all scripts to run the first time (never do this in a script) #####
    sketchybar --update
  '';
}
