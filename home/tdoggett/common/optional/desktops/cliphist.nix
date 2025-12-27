{ pkgs, ... }:
{
  # Clipboard history manager for Wayland
  home.packages = with pkgs; [
    cliphist
    wl-clipboard
  ];

  # Automatically track clipboard changes
  systemd.user.services.cliphist = {
    Unit = {
      Description = "Clipboard history service";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Persistence: .local/state/cliphist (declare in system-level persistence files)
}
