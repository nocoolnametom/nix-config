{ pkgs, ... }:
{
  # Discord doesn't have a programs.discord in home-manager yet
  home.packages = with pkgs; [ discord ];

  # Persistence: .config/discord (declare in system-level persistence files)
}
