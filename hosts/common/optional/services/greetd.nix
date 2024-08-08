{ pkgs, ... }:
{
  # Startup Greetd for wayland greeter
  services.greetd = {
    enable = true;
    settings = {
      default_session.command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
      default_session.user = "greeter";
    };
  };
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal"; # prevents errors from spamming screen!
    TTYReset = true;
    TTYVHanup = true;
    TTYVTDisallocate = true;
  };
  environment.etc."greetd/environments".text = ''
    Hyprland
    bash
  '';
}
