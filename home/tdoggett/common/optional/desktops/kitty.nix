{ lib, ... }:
{
  programs.kitty = {
    enable = lib.mkDefault true;
    shellIntegration.enableBashIntegration = lib.mkDefault true;
    settings = {
      enable_audio_bell = lib.mkDefault false;
      visual_bell_duration = lib.mkDefault "0.1";
    };
  };
}
