{ pkgs, ... }:
{
  # Zed editor doesn't have a programs.zed in home-manager yet
  home.packages = with pkgs; [ unstable.zed-editor ];

  # Persistence: .config/zed (declare in system-level persistence files)
}
