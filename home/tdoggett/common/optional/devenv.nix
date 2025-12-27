{ pkgs, ... }:
{
  home.packages = with pkgs; [ devenv ];

  # Persistence: .local/share/direnv (declare in system-level persistence files)
}
