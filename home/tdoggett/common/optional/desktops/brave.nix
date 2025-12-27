{ lib, ... }:
{
  programs.brave = {
    enable = lib.mkDefault true;
    commandLineArgs = [
      "--no-default-browser-check"
      "--restore-last-sesion"
    ];
  };

  # Persistence: .config/BraveSoftware/Brave-Browser (declare in system-level persistence files)
}
