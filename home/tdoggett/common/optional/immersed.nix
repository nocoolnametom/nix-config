{ pkgs, ... }:
{
  # User-level GUI packages to have installed
  home.packages = with pkgs; [ immersed ];

  # Persistence: .Immersed, .ImmersedConf (declare in system-level persistence files)
}
