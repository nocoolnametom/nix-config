{
  lib,
  config,
  ...
}:
let
  cfg = config.services.litra;
in
{
  options.services.litra = {
    enable = lib.mkEnableOption ''
      Litra Glow control: launchd agent auto-starts `litra-autotoggle` and
      a sketchybar widget toggles it on click. Requires the `litra` and
      `litra-autotoggle` homebrew formulae (see homebrew/default.nix).
      The sketchybar plugin scripts that actually drive the widget live in
      hosts/common/darwin/optional/services/sketchybar/plugins/litra*.nix
      and are conditionally added to the bar by sketchybar/default.nix.
    '';
  };

  config = lib.mkIf cfg.enable {
    # Auto-start litra-autotoggle on login. KeepAlive restarts it on crash;
    # suspending via the sketchybar click does a full `launchctl bootout`
    # so KeepAlive doesn't fight us.
    launchd.user.agents.litra-autotoggle = {
      command = "${config.homebrew.prefix}/bin/litra-autotoggle";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/tmp/litra-autotoggle.log";
        StandardErrorPath = "/tmp/litra-autotoggle.log";
      };
    };
  };
}
