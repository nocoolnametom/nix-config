{ lib, config, ... }:
{
  programs.firefox = {
    enable = lib.mkDefault true;

    # Define a default profile for Stylix to theme
    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;
    };

    # @TODO Remove once stateVersion is bumped beyond 26.05
    # Move config storage to new default
    configPath = "${config.xdg.configHome}/mozilla/firefox";
  };

  # Tell Stylix which profile(s) to theme (fixes build warning)
  stylix.targets.firefox.profileNames = [ "default" ];
}
