{ pkgs, ... }:
{
  # Slack doesn't have a programs.slack in home-manager yet
  home.packages = with pkgs; [ slack ];

  # Persistence: .config/Slack (declare in system-level persistence files)
}
