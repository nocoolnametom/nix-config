{ pkgs, ... }:
{
  # Obsidian doesn't have a programs.obsidian in home-manager yet
  home.packages = with pkgs; [ obsidian ];

  # Persistence: .config/obsidian (declare in system-level persistence files)
}
