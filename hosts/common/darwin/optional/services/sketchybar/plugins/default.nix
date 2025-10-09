{
  pkgs,
  sketchybar ? pkgs.sketchybar,
  ...
}:
rec {
  aerospace = import ./aerospace.nix { inherit pkgs sketchybar; };
  battery = import ./battery.nix { inherit pkgs sketchybar; };
  clock = import ./clock.nix { inherit pkgs sketchybar; };
  cpu = import ./cpu.nix { inherit pkgs sketchybar; };
  icon_map_fn = import ./icon_map_fn.nix { inherit pkgs sketchybar; };
  front_app = import ./front_app.nix { inherit pkgs sketchybar icon_map_fn; };
  space = import ./space.nix { inherit pkgs sketchybar; };
  space_windows = import ./space_windows.nix { inherit pkgs sketchybar icon_map_fn; };
  volume = import ./volume.nix { inherit pkgs sketchybar; };
}
