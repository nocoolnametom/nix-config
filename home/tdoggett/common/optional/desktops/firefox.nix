{ lib, ... }:
{
  programs.firefox = {
    enable = lib.mkDefault true;

    # Define a default profile for Stylix to theme
    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;
    };
  };

  # Tell Stylix which profile(s) to theme (fixes build warning)
  stylix.targets.firefox.profileNames = [ "default" ];
}
