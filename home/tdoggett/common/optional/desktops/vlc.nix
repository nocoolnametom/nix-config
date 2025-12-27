{ pkgs, ... }:
{
  # VLC doesn't have a programs.vlc in home-manager yet
  home.packages = with pkgs; [ vlc ];

  # Persistence: .config/vlc (declare in system-level persistence files)
}
