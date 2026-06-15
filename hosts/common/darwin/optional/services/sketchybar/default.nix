{
  lib,
  pkgs,
  config,
  configVars ? { },
  ...
}:
let
  plugins = import ./plugins {
    inherit pkgs config configVars;
    sketchybar = config.services.sketchybar.package;
    # UUIDs/names of calendars to surface in the widget — set per-host below.
    calendars = config.services.sketchybar.personalizedOptions.calendars;
    # Working-tree path (or null) — used by widgets that open their own
    # plugin source file on click. Comes from the shared `config.repoPath`
    # option defined by modules/darwin/repo-path.nix.
    repoPath = config.repoPath;
  };
  aerospace = "${config.services.aerospace.package}/bin/aerospace";
in
{
  # Per-host personalization that doesn't fit cleanly into nix-darwin's
  # upstream `services.sketchybar` options. Lives under a dedicated namespace
  # so it can't collide with anything nix-darwin defines now or later.
  options.services.sketchybar.personalizedOptions = {
    calendars = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Calendar identifiers (UUIDs preferred — they're not PII; display
        names also work) to surface in the sketchybar calendar widget.
        Discover yours with `icalBuddy calendars`. Empty list → all calendars.
      '';
      example = [ "684D9DAB-74E3-42D4-AA64-BEA3F8165EC9" ];
    };

    clockClickCommand = lib.mkOption {
      type = lib.types.str;
      default = "open -b com.apple.iCal";
      description = ''
        Shell command run when the clock (or calendar) widget is clicked.
        Defaults to opening Apple Calendar via its (historical) bundle ID;
        override per-host with `open -b <bundle-id>` to target a different
        calendar/tasks app.
      '';
      example = "open -b com.TickTick.task.mac";
    };

    compactPaddingItems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        List of sketchybar item names that get halved horizontal padding
        when the built-in display is attached. Populated by the
        sketchybar config itself, not user-facing.
      '';
    };

  };

  config =
    let
      baselineHeight = 30;
      # List of all sketchybar item names (excluding workspace indicators,
      # which are added in a loop and named space.$sid dynamically).
      # display_router applies per-item padding overrides to these.
      compactPaddingItems = [
        "chevron"
        "front_app"
        "aerospace_mode_compact"
        "space_separator"
        "aerospace_mode"
        "clock"
        "vpn"
        "weather"
        "battery"
        "cpu"
        "memory"
        "disk"
        "volume"
        "calendar"
        "calendar_dismiss"
        "now_playing"
      ]
      ++ lib.optional (config.services.litra.enable or false) "litra";
    in
    {

      services.sketchybar.personalizedOptions.compactPaddingItems = compactPaddingItems;

      services.sketchybar.enable = lib.mkDefault true;
      services.sketchybar.extraPackages = lib.mkDefault [
        config.services.aerospace.package
        pkgs.jq
        pkgs.display-info
      ];
      fonts.packages = [ pkgs.sketchybar-app-font ];
      services.sketchybar.config = lib.mkDefault ''
        ##### Bar Appearance #####
        # Configuring the general appearance of the bar.
        # These are only some of the options available. For all options see:
        # https://felixkratz.github.io/SketchyBar/config/bar
        # If you are looking for other colors, see the color picker:
        # https://felixkratz.github.io/SketchyBar/config/tricks#color-picker

        # Compute initial bar height from display-info. The display_router
        # script also runs on every display_change event (see below).
        initial_inset=$(${pkgs.display-info}/bin/display-info | /usr/bin/sed -n 's/^NOTCH_INSET=//p')
        initial_inset=''${initial_inset:-0}
        if [ "$initial_inset" -gt ${toString baselineHeight} ]; then
          initial_height=$initial_inset
        else
          initial_height=${toString baselineHeight}
        fi

        sketchybar --bar position=top height=$initial_height blur_radius=30 color=0x40000000

        ##### Changing Defaults #####
        # We now change some default values, which are applied to all further items.
        # For a full list of all available item properties see:
        # https://felixkratz.github.io/SketchyBar/config/items

        default=(
          padding_left=5
          padding_right=5
          icon.font="SFProDisplay Nerd Font:Bold:14.0"
          label.font="SFProDisplay Nerd Font:Semibold:14.0"
          icon.color=0xffffffff
          label.color=0xffffffff
          icon.padding_left=4
          icon.padding_right=4
          label.padding_left=4
          label.padding_right=4
        )
        sketchybar --default "${"$"}{default[@]}"

        ##### Display Router #####
        # Hidden item that responds to display_change events. Sets bar
        # height and writes the built-in-display flag file. Also runs once
        # at startup via the --update call at the end of this config.
        sketchybar --add item display_handler left \
                  --set display_handler \
                    drawing=off \
                    updates=on \
                    script="${plugins.display_router}" \
                  --subscribe display_handler display_change

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
            background.height=23 \
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
                  --set front_app icon.font="sketchybar-app-font:Regular:14.0" \
                    script="${plugins.front_app}" \
                  --subscribe front_app front_app_switched

        ##### Aerospace Mode Indicator (left, built-in only) #####
        # Sister item to the center `aerospace_mode`. Same script, same
        # subscriptions — but positioned on the left so it doesn't collide
        # with the notch. display_router toggles which of the two is
        # visible per attached display.
        sketchybar --add item aerospace_mode_compact left \
                  --set aerospace_mode_compact \
                    drawing=off \
                    background.corner_radius=5 \
                    background.height=23 \
                    background.padding_left=2 \
                    background.padding_right=2 \
                    label.font="SFProDisplay Nerd Font:Heavy:12.0" \
                    label.padding_left=10 \
                    label.padding_right=10 \
                    script="${plugins.aerospace_mode}" \
                  --subscribe aerospace_mode_compact aerospace_mode_change

        ##### Aerospace Mode Indicator (center) #####
        # Shows the active Aerospace binding mode with a color-coded label. Hidden
        # when in `main`. Triggered by aerospace bindings via the
        # `aerospace_mode_change` event (MODE=<name> payload). See:
        # plugins/aerospace_mode.nix for the color/label definitions and
        # hosts/common/darwin/optional/services/aerospace/default.nix for the
        # binding wire-up.
        sketchybar --add event aerospace_mode_change
        sketchybar --add item aerospace_mode center \
                  --set aerospace_mode \
                    drawing=off \
                    background.corner_radius=5 \
                    background.height=23 \
                    background.padding_left=2 \
                    background.padding_right=2 \
                    label.font="SFProDisplay Nerd Font:Heavy:12.0" \
                    label.padding_left=10 \
                    label.padding_right=10 \
                    script="${plugins.aerospace_mode}" \
                  --subscribe aerospace_mode aerospace_mode_change

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
                  --set clock update_freq=10 icon.drawing=off script="${plugins.clock}" \
                    click_script="${config.services.sketchybar.personalizedOptions.clockClickCommand}" \
                  --subscribe clock mouse.entered mouse.exited \
                  --add item vpn right \
                  --set vpn update_freq=10 icon=󰦞 script="${plugins.vpn}" \
                    click_script='open -b com.cisco.secureclient.gui' \
                --subscribe vpn mouse.entered mouse.exited

        ##### Litra Auto-Toggle Indicator (conditional) #####
        # Bright yellow bulb when the litra-autotoggle daemon is running, dim
        # gray when suspended. Click toggles the launchd agent (and turns the
        # light off when suspending). Hovering reveals a tooltip-style label
        # "Auto Camera Light: On/Off". Only added when
        # services.litra.enable = true on the host.
        # See: hosts/common/darwin/optional/services/litra/default.nix
        ${lib.optionalString (config.services.litra.enable or false) ''
          sketchybar --add event litra_state_changed
          sketchybar --add item litra right \
                    --set litra \
                      update_freq=5 \
                      icon=󰍵 \
                      icon.color=0xffe5d04a \
                      label.drawing=off \
                      script="${plugins.litra}" \
                      click_script="${plugins.litra_click}" \
                    --subscribe litra mouse.entered mouse.exited litra_state_changed
        ''}
                  sketchybar --add item weather right \
                  --set weather update_freq=600 icon=󰚕 script="${plugins.weather}" \
                    click_script="${plugins.weather_click}" \
                  --add item battery right \
                  --set battery update_freq=120 script="${plugins.battery}" \
                    click_script='open "x-apple.systempreferences:com.apple.Battery-Settings.extension"' \
                  --subscribe battery system_woke power_source_change \
                  --add item cpu right \
                  --set cpu update_freq=5 icon= script="${plugins.cpu}" \
                    click_script='open -a "Activity Monitor"' \
                  --add item memory right \
                  --set memory update_freq=5 icon=󰍛 script="${plugins.memory}" \
                    click_script='open -a "Activity Monitor"' \
                  --add item disk right \
                  --set disk update_freq=60 icon=󰋊 script="${plugins.disk}" \
                    click_script='open -a "Activity Monitor"' \
                  --add item volume right \
                  --set volume icon=󰕿 script="${plugins.volume}" \
                    click_script='open "x-apple.systempreferences:com.apple.Sound-Settings.extension"' \
                  --subscribe volume volume_change system_woke \
                --add event calendar_dismissed \
                --add item calendar right \
                  --set calendar update_freq=60 icon=󰃭 script="${plugins.calendar}" \
                    click_script="${config.services.sketchybar.personalizedOptions.clockClickCommand}" \
                  --subscribe calendar calendar_dismissed mouse.entered mouse.exited \
                --add item calendar_dismiss right \
                  --set calendar_dismiss \
                    drawing=off \
                    icon.drawing=off \
                    label="[X]" \
                    label.color=0xffcc4444 \
                    click_script="${plugins.calendar_dismiss}" \
                  --add item now_playing right \
                    --set now_playing update_freq=5 icon=󰎈 script="${plugins.now_playing}" \
                    --subscribe now_playing mouse.entered mouse.exited


        # Right items added in visual right-to-left order. Each --add right pushes
        # the new item to the LEFT of previous right items. Final layout
        # (right→left): clock, vpn, [litra,] weather, battery, cpu, memory, disk,
        # volume, calendar, calendar_dismiss ([X], only when NOW event), now_playing.

        ##### Force all scripts to run the first time (never do this in a script) #####
        sketchybar --update
      '';

    };
}
