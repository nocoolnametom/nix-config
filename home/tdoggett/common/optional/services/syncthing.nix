{ lib, ... }:
{
  services.syncthing = {
    enable = lib.mkDefault true;
  };

  # Persistence: .local/share/syncthing, .local/state/syncthing, Sync (declare in system-level persistence files)
}
